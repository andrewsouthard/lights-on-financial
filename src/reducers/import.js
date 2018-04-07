const initialState = {
  files: [],
};
const cs = (state = initialState, action) => {
  switch (action.type) {
    case "IMPORT_FILE":
      return { ...state, files: [...state.files, ...action.files] };
    case "REMOVE_IMPORT_FILE":
      if (action.file) {
        return {
          ...state,
          files: state.files.filter(f => f.name !== action.file.name),
        };
      }
      return state;
    default:
      return state;
  }
};
export default cs;
