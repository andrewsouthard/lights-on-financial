import React from "react";
import { connect } from "react-redux";
import FontAwesomeIcon from "@fortawesome/react-fontawesome";
import faTimes from "@fortawesome/fontawesome-free-solid/faTimes";
import CategorySelector from "../components/CategorySelector";
import ConfirmNavigation from "../components/ConfirmNavigation";

class TR extends React.Component {
  render() {
    const { categories, rules, updateRule, saveRules } = this.props;

    const createNewRule = (id, event, preformSave) => {
      const item = event.target.parentNode.parentNode.querySelector("select");
      const cat = item.options[item.selectedIndex].text;
      const match = event.target.value;
      preformSave({
        id: id,
        name: cat,
        tomatch: match,
      });
    };
    return (
      <div>
        <ConfirmNavigation />
        <div className="row" style={{ textAlign: "center" }}>
          <div className="col">
            <h1>Tagging Rules</h1>
            <a className="lof-btn">Add Rule</a>
            <a className="lof-btn" onClick={() => saveRules()}>
              Save Changes
            </a>
            <br />
            <table className="table table-striped">
              <tbody>
                <tr>
                  <th>Remove</th>
                  <th>Category</th>
                  <th>Rule</th>
                </tr>
                {rules.map((rule, index) => {
                  return (
                    <tr key={rule.id}>
                      <td onClick={() => console.log("remove")}>
                        <FontAwesomeIcon icon={faTimes} />
                      </td>
                      <td>
                        <CategorySelector
                          id={rule.id}
                          active={rule.category}
                          items={categories}
                          onChange={updateRule}
                        />
                      </td>
                      <td>
                        <input
                          value={rule.tomatch}
                          type="text"
                          onChange={event =>
                            createNewRule(rule.id, event, updateRule)
                          }
                        />
                      </td>
                    </tr>
                  );
                })}
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
  rules: state.rules.list,
  newrules: state.rules.newRules.length,
});
const mapDispatchToProps = dispatch => ({
  saveRules: () => dispatch({ type: "SAVE_RULES" }),
  updateRule: newRule => dispatch({ type: "UPDATE_NEW_RULES", rule: newRule }),
});
const TaggingRules = connect(mapStateToProps, mapDispatchToProps)(TR);
export default TaggingRules;
