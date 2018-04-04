import React from "react";
import { NavLink } from "react-router-dom";

export default class Header extends React.Component {
  render() {
    return (
      <div className="container-fluid">
        <title>Lights On Financial</title>
        <div className="row">
          <div className="col nopadding">
            <header>
              <ul className="list-inline">
                <li>
                  <NavLink exact to="/">
                    Spreadsheets
                  </NavLink>
                </li>
                <li>
                  <NavLink to="/createspreadsheet">Create Spreadsheet</NavLink>
                </li>
                <li>
                  <NavLink to="/transactioncategories">
                    Transaction Categories
                  </NavLink>
                </li>
                <li>
                  <NavLink to="/taggingrules">Tagging Rules</NavLink>
                </li>
              </ul>
            </header>
          </div>
        </div>
      </div>
    );
  }
}
