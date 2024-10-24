import { LightningElement, api } from "lwc";

export default class CustomDetailCell extends LightningElement {
  @api value;
  @api valueStyle;

  get showDetails() {
    return this.value.details !== undefined && this.value.details !== null;
  }
  get showLink() {
    return (this.value.recordName !== undefined && this.value.recordName !== null) && (this.value.recordURL !== undefined && this.value.recordURL !== null);
  }
  get showDate() {
    return this.value.recordDate !== undefined && this.value.recordDate !== null;
  }
}