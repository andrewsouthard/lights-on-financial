import { combineReducers } from "redux";
import cs from "./import";
import spreadsheets from "./spreadsheets";

const rootReducer = combineReducers({
  create: cs,
  spreadsheets,
});
export default rootReducer;
