import { combineReducers } from "redux";
import cs from "./import";
import categories from "./categories";
import spreadsheets from "./spreadsheets";
import rules from "./rules";

const rootReducer = combineReducers({
  create: cs,
  categories,
  spreadsheets,
  rules,
});
export default rootReducer;
