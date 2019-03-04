import { isEqual } from "lodash/core";

const initialState = {
  initialList: [],
  list: [],
  isDirty: false,
};

let numNewCategories = 0;
const emptyCategory = {
  id: null,
  name: "",
  income: -1,
};

const categories = (state = initialState, action) => {
  let idx;
  switch (action.type) {
    case "REMOVE_CATEGORY":
      idx = state.list.findIndex(c => c === action.category);
      const newList = [
        ...state.list.slice(0, idx),
        ...state.list.slice(idx + 1),
      ];
      return {
        ...state,
        isDirty: !isEqual(state.initialList, newList),
        list: newList,
      };
    case "ADD_CATEGORY":
      return {
        ...state,
        isDirty: true,
        list: [
          { ...emptyCategory, id: "NC-" + ++numNewCategories },
          ...state.list,
        ],
      };
    case "RESET_CATEGORIES":
      return {
        ...initialState,
        initialList: state.initialList,
        list: state.initialList,
      };
    case "UPDATE_CATEGORY":
      let setDirty = false;
      idx = state.list.findIndex(c => c.id === action.category.id);

      if (idx < 0 || !isEqual(action.category, state.initialList[idx])) {
        setDirty = true;
      }
      return {
        ...state,
        isDirty: setDirty,
        list: [
          ...state.list.slice(0, idx),
          action.category,
          ...state.list.slice(idx + 1),
        ],
      };
      return state;
    case "UPDATE_CATEGORIES":
      return {
        ...state,
        isDirty: false,
        initialList: action.list,
        list: action.list,
      };
    default:
      return state;
  }
};
export default categories;
