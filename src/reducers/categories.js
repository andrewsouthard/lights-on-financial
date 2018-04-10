const initialState = {
  list: [],
};
const categories = (state = initialState, action) => {
  switch (action.type) {
    case "UPDATE_CATEGORIES":
      return { ...state, list: action.list };
    default:
      return state;
  }
};
export default categories;
