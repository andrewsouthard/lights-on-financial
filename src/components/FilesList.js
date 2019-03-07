import React from "react";
import { connect } from "react-redux";
import path from "path";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faTimes } from "@fortawesome/fontawesome-free-solid";

const FileRow = (file, removeFile, updateFilename) => {
  const filename = path.basename(file);
  return (
    <tr key={file}>
      <td className="remove" onClick={() => removeFile(file)}>
        <FontAwesomeIcon icon={faTimes} />
      </td>
      <td className="filename">{filename}</td>
      <td className="account-nickname">
        <input
          onChange={event => {
            const val = event.target.value;
            if (val.length >= 2) updateFilename(file, val);
          }}
          type="text"
          name="nickname"
        />
      </td>
    </tr>
  );
};

class Files extends React.Component {
  render() {
    const { files, removeFile, updateFilename } = this.props;
    if (files && files.length > 0) {
      return (
        <table
          id="files"
          className="table table-condensed table-striped"
          style={{ display: files.length ? "initial" : "none" }}>
          <tbody>
            <tr>
              <th>Remove</th>
              <th>File Name</th>
              <th>Account Nickname</th>
            </tr>
            {files.map(file => FileRow(file, removeFile, updateFilename))}
          </tbody>
        </table>
      );
    } else {
      return <span />;
    }
  }
}
const mapStateToProps = state => {
  return {
    files: state.create.files,
  };
};
const mapDispatchToProps = dispatch => ({
  removeFile: file => dispatch({ type: "REMOVE_IMPORT_FILE", file: file }),
  updateFilename: (file, name) =>
    dispatch({ type: "UPDATE_IMPORT_FILENAME", file, name }),
});
const FilesList = connect(
  mapStateToProps,
  mapDispatchToProps
)(Files);
export default FilesList;
