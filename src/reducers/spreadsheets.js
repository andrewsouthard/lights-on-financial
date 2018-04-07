const initialState = {
  list: [],
};
const spreadsheets = (state = initialState, action) => {
  switch (action.type) {
    case "UPDATE_SPREADSHEETS":
      console.log(action);
      return { ...state, list: action.list };
    default:
      console.log(action);
      return state;
  }
};
export default spreadsheets;
