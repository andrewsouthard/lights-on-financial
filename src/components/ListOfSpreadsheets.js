import React from "react";
import { connect } from "react-redux";
import path from "path";

const SpreadsheetRow = (file, openFile, deleteFile) => {
  const name = path.basename(file);
  return (
    <li key={file}>
      {name}
      <ul className="list-inline">
        <li onClick={() => openFile(file)} className="open">
          Open
        </li>
        <li onClick={() => deleteFile(file)} className="delete">
          Delete
        </li>
      </ul>
    </li>
  );
};

class Spreadsheets extends React.Component {
  render() {
    const { spreadsheets, openFile, deleteFile } = this.props;
    if (spreadsheets && spreadsheets.length > 0) {
      return (
        <ul id="spreadsheets">
          {spreadsheets.map(file => SpreadsheetRow(file, openFile, deleteFile))}
        </ul>
      );
    } else {
      return <p>No spreadsheets found.</p>;
    }
  }
}
const mapStateToProps = state => {
  return {
    spreadsheets: state.spreadsheets.list,
  };
};
const mapDispatchToProps = dispatch => ({
  openFile: file => dispatch({ type: "OPEN_FILE", file: file }),
  deleteFile: file => dispatch({ type: "DELETE_FILE", file: file }),
});
const ListOfSpreadsheets = connect(mapStateToProps, mapDispatchToProps)(
  Spreadsheets
);
export default ListOfSpreadsheets;
