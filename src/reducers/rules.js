import { isEqual } from "lodash/core";

const initialState = {
  initialList: [],
  list: [],
  isDirty: false,
};
const emptyRule = {
  id: "",
  name: "",
  tomatch: "",
};
let numNewRules = 0;
let idx;
const rules = (state = initialState, action) => {
  switch (action.type) {
    case "REMOVE_RULE":
      idx = state.list.findIndex(r => r === action.rule);
      const newList = [
        ...state.list.slice(0, idx),
        ...state.list.slice(idx + 1),
      ];
      return {
        ...state,
        isDirty: !isEqual(state.initialList, newList),
        list: newList,
      };
    case "ADD_RULE":
      return {
        ...state,
        isDirty: true,
        list: [{ ...emptyRule, id: "NR-" + ++numNewRules }, ...state.list],
      };
    case "UPDATE_RULE":
      idx = state.list.findIndex(r => r.id === action.rule.id);
      let setDirty = false;
      if (idx < 0 || !isEqual(action.rule, state.initialList[idx])) {
        setDirty = true;
      }
      return {
        ...state,
        isDirty: setDirty,
        list: [
          ...state.list.slice(0, idx),
          action.rule,
          ...state.list.slice(idx + 1),
        ],
      };
    case "RESET_RULES":
      return {
        ...initialState,
        initialList: state.initialList,
        list: state.initialList,
      };
    case "UPDATE_ALL_RULES":
      return {
        ...state,
        isDirty: false,
        list: action.list,
        initialList: action.list,
      };
    default:
      return state;
  }
};
export default rules;
