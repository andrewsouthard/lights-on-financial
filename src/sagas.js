import { put, select, takeEvery } from "redux-saga/effects";
import { ipcRenderer as ipc, remote, shell } from "electron";
import path from "path";

const { dialog } = remote;

function* openFile(action) {
  try {
    yield shell.openItem(action.file);
  } catch (e) {
    yield put({ type: "FILE_OPEN_FAILED", message: e.message });
  }
}
function* importFile() {
  try {
    const files = dialog.showOpenDialog({
      filters: { name: "CSV,OFX,QFX", extensions: ["csv", "qfx", "ofx"] },
    });
    if (files) yield put({ type: "IMPORT_FILE", files });
  } catch (e) {
    yield put({ type: "FILE_IMPORT_FAILED", message: e.message });
  }
}

function* deleteFile(action) {
  try {
    const shortName = path.basename(action.file);
    dialog.showMessageBox(
      {
        type: "question",
        message: `Are you sure you want to delete the file ${shortName}?`,
        buttons: ["Yes", "No"],
        defaultId: 1,
      },
      /* The delete option is the first button so if the user didn't click that,
     don't do anything. */
      btnIdx => {
        if (btnIdx === 0) {
          ipc.send("delete-spreadsheet", action.file);
        }
      }
    );
  } catch (e) {
    yield put({ type: "FILE_DELETE_FAILED", message: e.message });
  }
}

function* initApp() {
  yield ipc.send("ready");
}

const getFilesToImport = state => state.create;

function* generateSpreadsheet(action) {
  /* Clear all errors */
  yield put({ type: "CLEAR_IMPORT_ERROR" });
  const createObj = yield select(getFilesToImport);
  const filesObj = [];
  console.log(createObj);

  /* Determine whether or not the previous imports should be kept. */
  const clearDB = action.shouldClearDB;

  /* Make sure all the files have names */
  let errIdx = -1;
  createObj.files.forEach((file, idx) => {
    if (!createObj.names[idx] || createObj.names[idx].length <= 2) {
      errIdx = idx;
    }
    filesObj.push({ nickname: createObj.names[idx], path: file });
  });

  if (errIdx >= 0) {
    yield put({
      type: "IMPORT_ERROR",
      message: "All accounts must have a name longer than 2 characters.",
    });
    return;
  }

  const d = new Date();
  const name =
    "cashflow" +
    "-" +
    d.getFullYear() +
    "-" +
    (d.getMonth() + 1) +
    "-" +
    d.getDay() +
    "-" +
    d.getHours() +
    d.getMinutes() +
    d.getSeconds() +
    ".xlsx";
  ipc.send("create-spreadsheet", name, clearDB, filesObj);
}

function* clearSpreadsheets() {
  yield put({ type: "CLEAR_SPREADSHEETS" });
}

const getRules = state => state.rules.list;
const getDirty = state => state.rules.isDirty;

function* saveRules() {
  const isDirty = yield select(getDirty);
  const rules = yield select(getRules);
  if (isDirty) {
    ipc.send("save-rules", rules);
  } else {
    /* The rules don't need to be saved. */
    yield put({ type: "RESET_RULES" });
  }
}

const getCategories = state => state.categories.list;
const getDirtyCategories = state => state.categories.isDirty;

function* saveCategories() {
  const isDirty = yield select(getDirtyCategories);
  const categories = yield select(getCategories);
  if (isDirty) {
    ipc.send("save-categories", categories);
  } else {
    /* The rules don't need to be saved. */
    yield put({ type: "RESET_CATEGORIES" });
  }
}

function* sagas() {
  yield takeEvery("INITIALIZE_APP", initApp);
  yield takeEvery("OPEN_FILE", openFile);
  yield takeEvery("SPREADSHEET_READY", clearSpreadsheets);
  yield takeEvery("GENERATE_SPREADSHEET", generateSpreadsheet);
  yield takeEvery("SAVE_CATEGORIES", saveCategories);
  yield takeEvery("SAVE_RULES", saveRules);
  yield takeEvery("SELECT_IMPORT_FILE", importFile);
  yield takeEvery("DELETE_FILE", deleteFile);
}

export default sagas;
