import React from "react";
/* Import the router items */
import { Route } from "react-router";
import { BrowserRouter as Router } from "react-router-dom";
/* Import the redux items and reducers */
import { createStore } from "redux";
import { Provider } from "react-redux";
import rootReducer from "./reducers/root";
/* Import pages */
import Header from "./components/Header";
import Home from "./pages/Home";
import CreateSpreadsheet from "./pages/CreateSpreadsheet";

const store = createStore(rootReducer);

// Now you can dispatch navigation actions from anywhere!
// store.dispatch(push('/foo'))
/*
            <Route path="/about" component={About} />
            <Route path="/topics" component={Topics} />
            */
export default class App extends React.Component {
  render() {
    return (
      <Provider store={store}>
        <Router>
          <div>
            <Header />
            <Route path="/createspreadsheet" component={CreateSpreadsheet} />
            <Route exact path="/" component={Home} />
          </div>
        </Router>
      </Provider>
    );
  }
}
