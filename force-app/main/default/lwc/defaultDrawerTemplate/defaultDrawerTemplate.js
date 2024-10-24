import { LightningElement, api } from "lwc";

export default class DefaultDrawerTemplate extends LightningElement {

  @api columns;
  @api row;
  @api isEditMode;

  @api
  getCustomCellComponents() {
    return this.template.querySelectorAll('c-custom-cell');
  }

  @api
  getInnerRow() {
    return this.row;
  }

}