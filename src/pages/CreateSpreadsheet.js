import React from "react";
import FilesList from "../components/FilesList";
import ImportActions from "../components/ImportActions";

export default class CreateSpreadsheet extends React.Component {
  render() {
    return (
      <div className="container-fluid">
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
