import React from "react";
import { connect } from "react-redux";
import FontAwesomeIcon from "@fortawesome/react-fontawesome";
import faTimes from "@fortawesome/fontawesome-free-solid/faTimes";
import CategorySelector from "../components/CategorySelector";
import ConfirmNavigation from "../components/ConfirmNavigation";

const ruleRow = (rule, categories, update, remove) => {
  const createNewRule = (id, event) => {
    const item = event.target.parentNode.parentNode.querySelector("select");
    const cat = item.options[item.selectedIndex].text;
    const match = event.target.value;
    update({
      id,
      name: cat,
      tomatch: match,
    });
  };
  return (
    <tr key={rule.id}>
      <td onClick={() => remove(rule)}>
        <FontAwesomeIcon icon={faTimes} />
      </td>
      <td>
        <CategorySelector
          id={rule.id}
          active={rule.category}
          items={categories}
          onChange={update}
        />
      </td>
      <td>
        <input
          value={rule.tomatch}
          type="text"
          onChange={event => createNewRule(rule.id, event)}
        />
      </td>
    </tr>
  );
};

class TR extends React.Component {
  render() {
    const {
      categories,
      rules,
      isDirty,
      addRule,
      updateRule,
      removeRule,
      saveRules,
      resetRules,
    } = this.props;
    return (
      <div>
        {ConfirmNavigation(isDirty, resetRules)}
        <div className="row" style={{ textAlign: "center" }}>
          <div style={{ marginTop: 20 }} className="col">
            <h2>Tagging Rules</h2>
            <br />
            <a className="lof-btn" onClick={() => addRule()}>
              Add Rule
            </a>
            <a className="lof-btn" onClick={() => saveRules()}>
              Save Changes
            </a>
            <br />
            <br />
            <table id="rules" className="table table-striped">
              <tbody>
                <tr>
                  <th>Remove</th>
                  <th>Category</th>
                  <th>Rule</th>
                </tr>
                {rules &&
                  rules.map(rule =>
                    ruleRow(rule, categories, updateRule, removeRule)
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
  isDirty: state.rules.isDirty,
  rules: state.rules.list,
});
const mapDispatchToProps = dispatch => ({
  addRule: () => dispatch({ type: "ADD_RULE" }),
  saveRules: () => dispatch({ type: "SAVE_RULES" }),
  updateRule: rule => dispatch({ type: "UPDATE_RULE", rule }),
  removeRule: rule => dispatch({ type: "REMOVE_RULE", rule }),
  resetRules: () => dispatch({ type: "RESET_RULES" }),
});
const TaggingRules = connect(mapStateToProps, mapDispatchToProps)(TR);
export default TaggingRules;
