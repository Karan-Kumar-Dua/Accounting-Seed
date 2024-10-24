import { api, LightningElement } from "lwc";

export default class CustomUrlCell extends LightningElement {

  @api recordName;
  @api recordLink;
  @api showLink = false;

}