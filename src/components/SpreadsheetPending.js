import React from "react";
import { Redirect } from "react-router-dom";
import { connect } from "react-redux";
import FontAwesomeIcon from "@fortawesome/react-fontawesome";
import faSpinner from "@fortawesome/fontawesome-free-solid/faSpinner";

class Pending extends React.Component {
  render() {
    const { done, pending, error } = this.props;
    if (pending === 0 && error === 0 && done) {
      return <Redirect to="/" />;
    } else if (pending && !done) {
      return (
        <div id="spreadsheet-pending">
          <FontAwesomeIcon icon={faSpinner} spin />
        </div>
      );
    } else {
      return <div />;
    }
  }
}
const mapStateToProps = state => ({
  done: state.create.spreadsheetDone,
  error: state.create.error,
  pending: state.create.spreadsheetPending,
});
const SpreadsheetPending = connect(mapStateToProps)(Pending);
export default SpreadsheetPending;
