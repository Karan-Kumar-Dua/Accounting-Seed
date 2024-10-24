import { api, LightningElement } from "lwc";
import { LabelService } from "c/utils";

export default class CustomSortButton extends LightningElement {
  @api sortedBy;
  @api sortedDirection;
  @api column;
  labels = LabelService;

  currentSortIcon = 'arrowup';

  get iconSortLink() {
    return "utility:" + this.currentSortIcon;
  }

  connectedCallback() {
    this.setCurrentSortIcon();
  }

  setCurrentSortIcon() {
    if (this.sortedBy === this.column.fieldName) {
      this.currentSortIcon = this.sortedDirection === "asc" ? "arrowup" : "arrowdown";
    }
  }

  handleSortAction() {
    this.currentSortIcon = this.currentSortIcon === "arrowdown" ? "arrowup" : "arrowdown";
    let sortDirection = this.currentSortIcon === "arrowdown" ? "desc" : "asc";
    this.dispatchEvent(new CustomEvent('selectsort', { detail: {fieldName : this.column.fieldName, sortDirection: sortDirection}}));
  }

}