import React from "react";
import NavigationPrompt from "react-router-navigation-prompt";

const ConfirmNavigation = (isDirty, sendClearState) => {
  return (
    <NavigationPrompt
      renderIfNotActive={false}
      // Confirm navigation if going to a path that does not start with current path:
      when={(crntLocation, nextLocation) =>
        !nextLocation.pathname.startsWith(crntLocation.pathname) && isDirty
      }>
      {({ onConfirm, onCancel }) => (
        <div id="confirmLeavePage">
          <p>
            Leaving will cause all changes to be discarded! Do you really want
            to leave?
          </p>
          <a
            onClick={() => {
              sendClearState();
              onConfirm();
            }}>
            Ok
          </a>
          <a onClick={onCancel}>Cancel</a>
        </div>
      )}
    </NavigationPrompt>
  );
};
export default ConfirmNavigation;
