import React from "react";
import FilesList from "../components/FilesList";
import ImportActions from "../components/ImportActions";
import SpreadsheetPending from "../components/SpreadsheetPending";

export default class CreateSpreadsheet extends React.Component {
  render() {
    return (
      <div>
        <SpreadsheetPending />
        <div className="row">
          <div className="col">
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
