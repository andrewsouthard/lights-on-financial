import React from "react";
import { connect } from "react-redux";

class IActions extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      shouldClearDB: false,
    };
  }
  toggleClearDB() {
    this.setState({ shouldClearDB: !this.state.shouldClearDB });
  }
  render() {
    const { numberOfFiles, importFile, generateSpreadsheet } = this.props;
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
              onClick={() => generateSpreadsheet(this.state.shouldClearDB)}
              disabled={numberOfFiles < 1 ? true : false}>
              Generate Spreadsheet
            </button>
          </li>
        </ul>
        <div id="clearDB">
          <input
            type="checkbox"
            name="shouldClearDB"
            onChange={() => this.toggleClearDB()}
          />
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
  generateSpreadsheet: shouldClearDB =>
    dispatch({ type: "GENERATE_SPREADSHEET", shouldClearDB }),
});
const ImportActions = connect(mapStateToProps, mapDispatchToProps)(IActions);
export default ImportActions;
