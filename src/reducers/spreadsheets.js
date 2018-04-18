const initialState = {
  list: [],
};
const spreadsheets = (state = initialState, action) => {
  console.log(action);
  switch (action.type) {
    case "UPDATE_SPREADSHEETS":
      return { ...state, list: action.list };
    default:
      return state;
  }
};
export default spreadsheets;
