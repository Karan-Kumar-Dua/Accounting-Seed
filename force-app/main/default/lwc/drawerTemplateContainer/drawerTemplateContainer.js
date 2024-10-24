import { LightningElement, api } from "lwc";
import defaultTmpl from './defautTemplate.html';
import bdcUnmatchedTmpl from './bdcUnmatchedTemplate.html';

export default class DrawerTemplateContainer extends LightningElement {

  @api templateName = 'c-default-drawer-template';
  @api columns;
  @api row;
  @api isEditMode;

  render() {
    switch(this.templateName) {
      case 'c-bdc-unmatched-drawer-template':
        return bdcUnmatchedTmpl;
      default:
        return defaultTmpl;
    }
  }

  @api
  getCurrentTemplate() {
    if (this.templateName == null || this.templateName === '') {
      this.templateName = 'c-default-drawer-template';
    }
    return this.template.querySelector(this.templateName);
  }

}