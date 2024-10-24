import { api, LightningElement } from "lwc";
import FinReporterViewStore from './finReporterViewStore';
import { LabelService } from 'c/utils';
import Labels from "./labels";

export default class FinReporterViewContainer extends LightningElement {
  labels = {...LabelService, ...Labels};
  headers = [];
  items = [];
  isLoaded = false;
  isEmpty = false;
  reportStore = new FinReporterViewStore();

  @api
  get reportValues() {
    return this._reportValues;
  }
  set reportValues(value) {
    if (value !== undefined) {
      this._reportValues = value;
      if (this._reportValues.reportValues.length > 0) {
        this.getHeadersAndItems(this._reportValues);
      }
      else {
        this.isEmpty = true;
      }
      this.isLoaded = true;
    }
  }

  @api
  get settings() {
    return this._settings;
  }
  set settings(value) {
    if (value !== undefined) {
      this._settings = value;
      this.reportStore.addSettings(this._settings);
    }
  }

  @api expandAll() {
    this.expandCollapse(true);
  }

  @api collapseAll() {
    this.expandCollapse(false);
  }

  expandCollapse(isExpand) {
    let report = this.reportView();
    if (report) {
      report.expandCollapseAll(isExpand);
    }
  }

  getHeadersAndItems(values) {
    this.reportStore.addItems(values);
    this.headers = this.reportStore.getHeaders();
    this.items = this.reportStore.getItems();
  }

  reportView = () => this.template.querySelector('c-fin-reporter-generic-view-data');

}