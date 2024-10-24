import { LightningElement,api } from "lwc";
import { LabelService } from "c/utils";


export default class CustomDataTableRowError extends LightningElement {
  @api row;
  labels = LabelService;

  get message() {
    return this.row.errors !== undefined && this.row.errors.length > 0 ? this.row.errors[0] : '';
  }

  renderedCallback() {
    if (this.row.errors !== undefined && this.row.errors.length > 0) {
      this.dispatchEvent(new CustomEvent('showmessageaction', { detail: this.row.Id }));
    }
    else {
      this.handleAction();
    }
  }

  handleAction() {
    this.dispatchEvent(new CustomEvent('closeaction', { detail: this.row.Id }));
  }




}