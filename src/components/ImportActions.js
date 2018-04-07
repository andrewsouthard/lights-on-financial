import React from "react";
import { connect } from "react-redux";

class IActions extends React.Component {
  render() {
    const { numberOfFiles, importFile } = this.props;
    return (
      <div>
        <ul id="importActions" className="list-inline">
          <li>
            <button onClick={() => importFile()} className="btn lof-btn">
              Add File
            </button>
          </li>
          <li>
            <button
              id="generate-spreadsheet"
              className="btn lof-btn"
              disabled={numberOfFiles < 1 ? true : false}>
              Generate Spreadsheet
            </button>
          </li>
        </ul>
        <div id="clearDB">
          <input type="checkbox" name="shouldClearDB" />
          <label htmlFor="shouldClearDB">
            &nbsp;Remove previously imported transactions.<br />
          </label>
        </div>
      </div>
    );
  }
}
const mapStateToProps = state => ({
  numberOfFiles: state.create.files.length,
});
const mapDispatchToProps = dispatch => ({
  importFile: () => dispatch({ type: "SELECT_IMPORT_FILE" }),
});
const ImportActions = connect(mapStateToProps, mapDispatchToProps)(IActions);
export default ImportActions;
