import { app, BrowserWindow, dialog, ipcMain as ipc } from "electron";
import installExtension, {
  REACT_DEVELOPER_TOOLS,
} from "electron-devtools-installer";
import { enableLiveReload } from "electron-compile";
import is from "electron-is";
import fs from "fs";
import url from "url";
import sql from "sql.js";
import path from "path";
import { promisify } from "util";
import _ from "lodash/core";

// Create a file execer object.
import { execFileSync } from "child_process";

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let mainWindow;

// Constants
const SRC_DIR = app.getAppPath();
const OUTPUT_DIR = app.getPath("userData");
const DATABASE = path.join(OUTPUT_DIR, "lof.sqlite");
const DEBUG = 1;
const appState = {
  accounts: [],
  categories: [],
  overwriteTransactions: 0,
  rules: [],
  spreadsheets: [],
  transactions: [],
};

const isDevMode = process.execPath.match(/[\\/]electron/);
const createWindow = () => {
  // Create the browser window.
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    titleBarStyle: "hidden",
  });

  /* Remove the default menus */
  if (!is.macOS() && is.production()) {
    mainWindow.setMenu(null);
  }

  // and load the index.html of the app.
  mainWindow.loadURL(
    url.format({
      pathname: path.join(SRC_DIR, "src/index.html"),
      protocol: "file:",
      slashes: true,
    })
  );

  // Open the DevTools.
  if (isDevMode) {
    enableLiveReload({ strategy: "react-hmr" });
    installExtension(REACT_DEVELOPER_TOOLS);
    mainWindow.webContents.openDevTools();
  }

  // Emitted when the window is closed.
  mainWindow.on("closed", () => {
    // Dereference the window object, usually you would store windows
    // in an array if your app supports multi windows, this is the time
    // when you should delete the corresponding element.
    mainWindow = null;
  });
};
/* Define a function to setup error logging */
const showError = (event, message, type = "DEFAULT") => {
  if (DEBUG) console.log(message);
  event.sender.send("internal-error", type, message);
};

const access = promisify(fs.access);
const updateAppState = async event => {
  try {
    await fs.readdir(OUTPUT_DIR, (err, dir) => {
      for (const filePath of dir) {
        if (
          filePath.match("xlsx$") &&
          !appState.spreadsheets.includes(path.join(OUTPUT_DIR, filePath))
        ) {
          appState.spreadsheets.push(path.join(OUTPUT_DIR, filePath));
        }
      }
      appState.spreadsheets.sort(
        (a, b) =>
          fs.statSync(b).mtime.getTime() - fs.statSync(a).mtime.getTime()
      );
    });
  } catch (err) {
    showError(event, `Failed to get spreadsheets!\n ${err}`);
  }
  /* See if the database exists. If so, populate the appState. */
  try {
    await process.chdir(path.join(SRC_DIR, "backend"));
    await execFileSync("perl", ["createDatabase.pl", DATABASE]);
    await access(DATABASE, fs.constants.R_OK | fs.constants.W_OK);

    const filebuffer = fs.readFileSync(DATABASE);

    // Load the db
    const db = new sql.Database(filebuffer);
    // Clear the current settings
    appState.accounts = [];
    appState.categories = [];
    appState.rules = [];
    appState.transactions = [];

    let stmt = db.prepare("SELECT * FROM accounts");
    while (stmt.step()) {
      appState.accounts.push(stmt.getAsObject());
    }

    stmt = db.prepare("SELECT * FROM categories ORDER BY name");
    while (stmt.step()) {
      appState.categories.push(stmt.getAsObject());
    }

    stmt = db.prepare("SELECT * FROM rules ORDER BY category");
    while (stmt.step()) {
      appState.rules.push(stmt.getAsObject());
    }

    stmt = db.prepare("SELECT * FROM transactions");
    while (stmt.step()) {
      appState.transactions.push(stmt.getAsObject());
    }

    stmt.free();
  } catch (err) {
    showError(event, `Error updating state!\n ${err}`);
    /* Trigger the database to be created. */
    appState.overwriteTransactions = 1;
  }
};
const performSetup = async event => {
  try {
    await access(OUTPUT_DIR, fs.constants.R_OK | fs.constants.W_OK);
    await updateAppState(event);
  } catch (err) {
    showError(event, `Failed to access ${OUTPUT_DIR}!\n Fatal Error!`);
  }
};

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on("ready", createWindow);
app.on("ready", performSetup);
ipc.on("ready", event => {
  event.sender.send("spreadsheets-list", appState.spreadsheets);
  event.sender.send("rules-list", appState.rules);
  event.sender.send("categories-list", appState.categories);
});

// Quit when all windows are closed.
app.on("window-all-closed", () => {
  // On OS X it is common for applications and their menu bar
  // to stay active until the user quits explicitly with Cmd + Q
  if (process.platform !== "darwin") {
    app.quit();
  }
});

app.on("activate", () => {
  // On OS X it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (mainWindow === null) {
    createWindow();
  }
});

const saveCategories = async (event, categories) => {
  try {
    // Load the db
    const filebuffer = fs.readFileSync(DATABASE);
    const db = new sql.Database(filebuffer);

    let sqlStr = "";
    /* Process all of the new and updated categories. */
    categories.forEach(cat => {
      const existingCat = appState.categories.find(c => _.isEqual(c, cat));
      if (!existingCat) {
        if (typeof cat.id !== "number") {
          sqlStr += `INSERT INTO categories VALUES(NULL,"${cat.name}","${
            cat.income
          }");`;
        } else {
          sqlStr += `UPDATE categories SET name="${cat.name}",income=${
            cat.income
          }" WHERE id=${cat.id};`;
        }
      }
    });
    /* Process any of the deleted categories. */
    appState.categories.forEach(cat => {
      const existingCat = categories.find(c => c.id === cat.id);
      if (!existingCat) {
        sqlStr += `DELETE FROM categories WHERE id=${cat.id};`;
      }
    });
    if (DEBUG) console.log(sqlStr);
    /* Update the database */
    db.exec(sqlStr);
    /* Write the db to disk. */
    const data = db.export();
    const buffer = Buffer.alloc(data.length, data);
    fs.writeFileSync(DATABASE, buffer);
    db.close();
    /* Update the app state from the db */
    await updateAppState();
    /* Send the renderer the updated rules */
    event.sender.send("save-categories-complete", appState.categories);
  } catch (error) {
    showError(event, error);
  }
};
const saveRules = async (event, rules) => {
  try {
    // Load the db
    const filebuffer = fs.readFileSync(DATABASE);
    const db = new sql.Database(filebuffer);

    let sqlStr = "";
    /* Process all of the new and updated rules */
    rules.forEach(rule => {
      const existingRule = appState.rules.find(r => _.isEqual(r, rule));
      if (!existingRule) {
        if (typeof rule.id !== "number") {
          sqlStr += `INSERT INTO rules VALUES(NULL,"${rule.name}","${
            rule.tomatch
          }");`;
        } else {
          sqlStr += `UPDATE rules SET category="${rule.name}",tomatch="${
            rule.tomatch
          }" WHERE id=${rule.id};`;
        }
      }
    });
    /* Process any of the deleted rules. */
    appState.rules.forEach(rule => {
      const existingRule = rules.find(r => r.id === rule.id);
      if (!existingRule) {
        sqlStr += `DELETE FROM rules WHERE id=${rule.id};`;
      }
    });
    if (DEBUG) console.log(sqlStr);
    /* Update the database */
    db.exec(sqlStr);
    /* Write the db to disk. */
    const data = db.export();
    const buffer = Buffer.alloc(data.length, data);
    fs.writeFileSync(DATABASE, buffer);
    db.close();
    /* Update the app state from the db */
    await updateAppState();
    /* Send the renderer the updated rules */
    event.sender.send("save-rules-complete", appState.rules);
  } catch (error) {
    showError(event, error);
  }
};
const createSpreadsheet = async (event, name, shouldClearDB, filesObj) => {
  try {
    /* Clear the transactions from the database if the user requests it */
    if (shouldClearDB) {
      try {
        await access(DATABASE, fs.constants.R_OK | fs.constants.W_OK);
        const filebuffer = fs.readFileSync(DATABASE);

        // Load the db
        const db = new sql.Database(filebuffer);
        db.exec("DELETE FROM transactions");
        const data = db.export();
        const buffer = Buffer.alloc(data.length, data);
        fs.writeFileSync(DATABASE, buffer);
        db.close();
      } catch (err) {
        showError(
          event,
          `Error removing transactions from the database!\n ${err}`
        );
      }
    }

    await process.chdir(path.join(SRC_DIR, "backend"));
    for (const file of filesObj) {
      const stdout = execFileSync("perl", [
        "import.pl",
        file.path,
        file.nickname,
        appState.overwriteTransactions,
        DATABASE,
      ]);
      if (DEBUG) {
        console.log(stdout.toString("utf8"));
      }
    }
    execFileSync("perl", ["outToSpreadsheet.pl", DATABASE]);
    console.log(`new name is ${name}`);

    await fs.rename(
      path.join(OUTPUT_DIR, "budget-sheet.xlsx"),
      path.join(OUTPUT_DIR, name),
      err => {
        if (err) {
          showError(event, err);
        }
      }
    );

    /* Update the list of spreadsheets */
    await updateAppState();
    if (appState.spreadsheets.length) {
      event.sender.send("spreadsheets-list", appState.spreadsheets);
    } else {
      event.sender.send("zero-spreadsheets-list");
    }

    /* Navigate to the main page
    await mainWindow.loadURL(
      url.format({
        pathname: path.join(OUTPUT_DIR, "index.html"),
        protocol: "file:",
        slashes: true,
      })
    );
    */

    // WHEN READY
    await event.sender.send("spreadsheet-ready", name);
  } catch (err) {
    showError(event, err.stdout.toString(), "IMPORT");
  }
};

const deleteSpreadsheet = async (event, filename) => {
  if (DEBUG) console.log(`delete file ${filename}`);

  /* Remove the file */
  try {
    await fs.unlinkSync(filename);
    /* Update the list of spreadsheets  */
    appState.spreadsheets = appState.spreadsheets.filter(
      name => name !== filename
    );
    event.sender.send("spreadsheets-list", appState.spreadsheets);
  } catch (err) {
    console.log(err);
    throw err;
  }
};

ipc.on("create-spreadsheet", createSpreadsheet);
ipc.on("delete-spreadsheet", deleteSpreadsheet);
ipc.on("get-transactions", event => {
  event.sender.send("transactions-sent", appState.transactions);
});
ipc.on("get-rules", event => {
  event.sender.send("rules-sent", appState.rules);
});
ipc.on("get-categories", event => {
  event.sender.send("categories-sent", appState.categories);
});
ipc.on("save-categories", saveCategories);
ipc.on("save-rules", saveRules);
ipc.on("open-file-dialog", event => {
  const files = dialog.showOpenDialog({
    properties: ["openFile"],
    filters: [{ name: "Supported Files", extensions: ["csv", "ofx", "qfx"] }],
  });
  if (DEBUG) console.log("send selected-file");
  if (files) event.sender.send("selected-file", files);
});
