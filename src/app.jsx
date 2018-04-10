import React from "react";
/* Import the IPC object to setup listening. */
import { ipcRenderer as ipc } from "electron";
/* Import the router items */
import { Switch, Route } from "react-router";
import { BrowserRouter as Router } from "react-router-dom";
/* Import the redux items and reducers */
import { createStore, applyMiddleware } from "redux";
import { Provider } from "react-redux";
import rootReducer from "./reducers/root";
/* Import redux-saga and sagas */
import createSagaMiddleware from "redux-saga";
import sagas from "./sagas";
/* Import pages */
import Header from "./components/Header";
import Home from "./pages/Home";
import CreateSpreadsheet from "./pages/CreateSpreadsheet";
import TransactionCategories from "./pages/TransactionCategories";
import TaggingRules from "./pages/TaggingRules";

/* Create the saga middleware, store and run the middleware */
const sagaMiddleware = createSagaMiddleware();
const store = createStore(rootReducer, applyMiddleware(sagaMiddleware));
sagaMiddleware.run(sagas);

store.dispatch({ type: "INITIALIZE_APP" });

/* Setup IPC Listeners. All we will do is dispatch actions from here. All data
   parsing and logic is in the reducers.
*/

ipc.on("spreadsheets-list", (event, spreadsheets) => {
  store.dispatch({ type: "UPDATE_SPREADSHEETS", list: spreadsheets });
});
ipc.on("categories-list", (event, categories) => {
  store.dispatch({ type: "UPDATE_CATEGORIES", list: categories });
});
ipc.on("rules-list", (event, rules) => {
  store.dispatch({ type: "UPDATE_RULES", list: rules });
});
ipc.on("spreadsheet-ready", (event, name) => {
  store.dispatch({ type: "SPREADSHEET_READY", name });
});

export default class App extends React.Component {
  render() {
    return (
      <Provider store={store}>
        <Router>
          <div>
            <Header />
            <Switch>
              <Route path="/createspreadsheet" component={CreateSpreadsheet} />
              <Route
                path="/transactioncategories"
                component={TransactionCategories}
              />
              <Route path="/taggingrules" component={TaggingRules} />
              <Route path="/" component={Home} />
            </Switch>
          </div>
        </Router>
      </Provider>
    );
  }
}
