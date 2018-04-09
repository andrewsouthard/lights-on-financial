const initialState = {
  files: [],
  names: [],
  spreadsheetPending: 0,
  spreadsheetDone: 0,
};
const cs = (state = initialState, action) => {
  switch (action.type) {
    case "UPDATE_IMPORT_FILENAME":
      const idx = state.files.findIndex(f => f === action.file);
      console.log(state.names);
      return {
        ...state,
        names: [
          ...state.names.slice(0, idx),
          action.name,
          ...state.names.slice(idx + 1),
        ],
      };
    case "IMPORT_FILE":
      console.log(state.files);
      return { ...state, files: [...state.files, ...action.files] };
    case "REMOVE_IMPORT_FILE":
      if (action.file) {
        return {
          ...state,
          files: state.files.filter(f => f.name !== action.file.name),
        };
      }
      return state;
    case "GENERATE_SPREADSHEET":
      return { ...state, spreadsheetPending: 1 };
    case "SPREADSHEET_READY":
      return { ...initialState, spreadsheetDone: 1 };
    case "CLEAR_SPREADSHEETS":
      return initialState;
    default:
      return state;
  }
};
export default cs;
