const initialState = {
  list: [],
  newRules: [],
};
const rules = (state = initialState, action) => {
  switch (action.type) {
    case "XXX_UPDATE_RULES":
      return {
        ...state,
        names: [
          ...state.names.slice(0, idx),
          action.name,
          ...state.names.slice(idx + 1),
        ],
      };
    case "UPDATE_NEW_RULES":
      return {
        ...state,
        newRules: [...state.newRules, action.rule],
      };
    case "SAVE_RULES":
      console.log(state.newRules);
      return state;
    case "UPDATE_RULES":
      return { ...state, list: action.list };
    default:
      return state;
  }
};
export default rules;
