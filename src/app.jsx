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

/* Create the saga middleware, store and run the middleware */
const sagaMiddleware = createSagaMiddleware();
const store = createStore(rootReducer, applyMiddleware(sagaMiddleware));
sagaMiddleware.run(sagas);

store.dispatch({ type: "INITIALIZE_APP" });

/* Setup IPC Listeners. All we will do is dispatch actions from here. All data
   parsing and logic is in the reducers.
*/
ipc.on("zero-spreadsheets-list", event => {
  store.dispatch({ type: "UPDATE_SPREADSHEETS", list: [] });
});

ipc.on("spreadsheets-list", (event, spreadsheets) => {
  store.dispatch({ type: "UPDATE_SPREADSHEETS", list: spreadsheets });
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
              <Route path="/" component={Home} />
            </Switch>
          </div>
        </Router>
      </Provider>
    );
  }
}
