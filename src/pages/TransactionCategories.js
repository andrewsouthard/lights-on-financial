import React from "react";
import { connect } from "react-redux";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faTimes } from "@fortawesome/fontawesome-free-solid";
import ConfirmNavigation from "../components/ConfirmNavigation";

const catRow = (cat, updateCategory, remove) => {
  const updateRow = (id, event) => {
    const tableRow = event.target.parentNode.parentNode;
    const item = tableRow.querySelector("select");
    const income = item.options[item.selectedIndex].text;
    const name = tableRow.querySelector("input").value;
    updateCategory({
      id,
      name,
      income,
    });
  };
  if (typeof cat.id === "number") {
    return (
      <tr key={cat.id}>
        <td onClick={() => remove(cat)}>
          <FontAwesomeIcon icon={faTimes} />
        </td>
        <td>{cat.name}</td>
        <td>{cat.income ? "Income" : "Expenditure"}</td>
      </tr>
    );
  } else {
    return (
      <tr key={cat.id}>
        <td onClick={() => remove(cat)}>
          <FontAwesomeIcon icon={faTimes} />
        </td>
        <td>
          <input
            type="text"
            value={cat.name}
            onChange={e => updateRow(cat.id, e)}
          />
        </td>
        <td>
          <select onChange={e => updateRow(cat.id, e)}>
            <option value="0" name="0">
              Expenditure
            </option>
            <option value="1" name="1">
              Income
            </option>
          </select>
        </td>
      </tr>
    );
  }
};

class TC extends React.Component {
  render() {
    const {
      addCategory,
      categories,
      isDirty,
      resetCategories,
      removeCategory,
      saveCategories,
      updateCategory,
    } = this.props;
    return (
      <div>
        {ConfirmNavigation(isDirty, resetCategories)}
        <div className="row" style={{ textAlign: "center" }}>
          <div style={{ marginTop: 20 }} className="col">
            <h2>Transaction Categories</h2>
            <br />
            <a className="lof-btn" onClick={() => addCategory()}>
              Add Category
            </a>
            <a className="lof-btn" onClick={() => saveCategories()}>
              Save Changes
            </a>
            <br />
            <br />
            <table className="table table-striped">
              <tbody>
                <tr>
                  <th>Remove</th>
                  <th>Category Name</th>
                  <th>Category Type</th>
                </tr>
                {categories.map(cat =>
                  catRow(cat, updateCategory, removeCategory)
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    );
  }
}
const mapStateToProps = state => ({
  categories: state.categories.list,
  isDirty: state.categories.isDirty,
});
const mapDispatchToProps = dispatch => ({
  addCategory: () => dispatch({ type: "ADD_CATEGORY" }),
  saveCategories: () => dispatch({ type: "SAVE_CATEGORIES" }),
  removeCategory: category => dispatch({ type: "REMOVE_CATEGORY", category }),
  resetCategories: () => dispatch({ type: "RESET_CATEGORIES" }),
  updateCategory: category => dispatch({ type: "UPDATE_CATEGORY", category }),
});
const TransactionCategories = connect(
  mapStateToProps,
  mapDispatchToProps
)(TC);
export default TransactionCategories;
