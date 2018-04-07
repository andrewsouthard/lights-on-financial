import React from "react";
import ListOfSpreadsheets from "../components/ListOfSpreadsheets";

export default class Home extends React.Component {
  render() {
    return (
      <div className="container-fluid">
        <div className="row">
          <div id="listOfSpreadsheets" className="col">
            <h2>Spreadsheets</h2>
            <div>
              <ListOfSpreadsheets />
            </div>
          </div>
        </div>
      </div>
    );
  }
}
