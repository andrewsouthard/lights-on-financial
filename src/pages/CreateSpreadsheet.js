import React from "react";

export default class CreateSpreadsheet extends React.Component {
  render() {
    return (
      <div className="container-fluid">
        <div className="row">
          <div className="col">
            <form id="uploadForm" method="post">
              <table id="files" className="table table-condensed table-striped">
                <tr>
                  <th>Remove</th>
                  <th>File Name</th>
                  <th>Account Nickname</th>
                </tr>
              </table>
              <input
                type="file"
                name="fileToUpload"
                id="fileToUpload"
                onChange="fileSelected();"
                accept=".qfx,.ofx,.csv"
                required
              />
              <br />
              <span id="errorMessage" />
              <br />
              <div id="clearDB">
                <input type="checkbox" name="shouldClearDB" />
                <label htmlFor="shouldClearDB">
                  &nbsp;Remove previously imported transactions.<br />
                </label>
              </div>
              <ul id="importActions" className="list-inline">
                <li>
                  <label htmlFor="fileToUpload" className="btn lof-btn">
                    Add File
                  </label>
                </li>
                <li>
                  <button
                    id="generate-spreadsheet"
                    className="btn lof-btn"
                    disabled>
                    Generate Spreadsheet
                  </button>
                </li>
              </ul>
            </form>
          </div>
        </div>
      </div>
    );
  }
}
