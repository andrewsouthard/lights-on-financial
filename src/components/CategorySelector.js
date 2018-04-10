import React from "react";

export default class CategorySelector extends React.Component {
  formatRule(id, event, onChange) {
    const cat = event.target.value;
    const item = event.target.parentNode.parentNode.querySelector("input");
    const match = item.value;
    onChange({
      id: id,
      name: cat,
      tomatch: match,
    });
  }
  render() {
    const { active, id, items, onChange } = this.props;
    if (items) {
      return (
        <select
          onChange={event => this.formatRule(id, event, onChange)}
          defaultValue={active}>
          {items.map(cat => (
            <option key={cat.id} value={cat.name}>
              {cat.name}
            </option>
          ))}
        </select>
      );
    } else {
      return <span />;
    }
  }
}
