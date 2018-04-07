import { put, takeEvery } from "redux-saga/effects";
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
    yield put({ type: "IMPORT_FILE", files });
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

function* sagas() {
  yield takeEvery("INITIALIZE_APP", initApp);
  yield takeEvery("OPEN_FILE", openFile);
  yield takeEvery("SELECT_IMPORT_FILE", importFile);
  yield takeEvery("DELETE_FILE", deleteFile);
}

export default sagas;
