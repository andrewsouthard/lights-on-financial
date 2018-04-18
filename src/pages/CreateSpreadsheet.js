import React from "react";
import FilesList from "../components/FilesList";
import ImportActions from "../components/ImportActions";
import SpreadsheetPending from "../components/SpreadsheetPending";

export default class CreateSpreadsheet extends React.Component {
  render() {
    return (
      <div>
        <SpreadsheetPending />
        <div className="row" style={{ textAlign: "center" }}>
          <div style={{ marginTop: 20 }} className="col">
            <h2>Create Spreadsheet</h2>
            <br />
            <br />
            <FilesList />
            <br />
            <span id="errorMessage" />
            <br />
            <ImportActions />
          </div>
        </div>
      </div>
    );
  }
}
