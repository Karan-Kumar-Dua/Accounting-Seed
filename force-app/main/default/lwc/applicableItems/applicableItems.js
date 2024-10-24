import { LightningElement, api, track } from 'lwc';
import { LabelService } from "c/utils";
import Labels from './labels';

export default class ApplicableItems extends LightningElement {
    labels = {...LabelService, ...Labels};
    pageOffset = 0;

    @api pageSize = 15;
    @api keyField;
    @api columns;
    @api page;
    @api maxRecordsDisplayed;
    @api suppressMoreRecordsMessage = false;
    @api sortedBy;
    @api sortedDirection;
    @api objectName;
    @api showCheckboxColumn = false;

    @api
    get items() {
        return this.data;
    }
    set items(value = []) {
        this.originalDataLen = value.length;
        this.data = (this.maxRecordsDisplayed && (value.length >= this.maxRecordsDisplayed))
            ? value.slice(0, this.maxRecordsDisplayed) 
            : value;
        this.page = this.data.slice(this.pageOffset, this.pageOffset + this.pageSize);
        this.totalRecords = this.data.length;
        this.objectName = this.objectName !== undefined ? this.objectName : LabelService.commonBilling;
    }

    @api
    showFirstPage() {
        const paginator = this.template.querySelector("c-paginator");
        if (paginator) {
            paginator.goToPage(1);
        }
        this.pageOffset = 0;
        this.page = this.data.slice(0, this.pageSize);        
    }

    @api
    getCurrentPageItems() {
        return this.page;
    }

    @api
    getSelectedRows() {
        return this.template.querySelector('c-applicable-items-custom-datatable').getSelectedRows()
    }
    
    @track data;    
    @track totalRecords;

    get showTable() {
        return this.data&& this.data.length > 0;
    }

    get hideCheckboxColumn() {
        return !this.showCheckboxColumn;
    }

    get moreRecordsExist() {
        return this.originalDataLen && this.maxRecordsDisplayed && (this.originalDataLen > this.maxRecordsDisplayed) && !this.suppressMoreRecordsMessage;
    }

    handlePageChange({ detail: offset }) {
        this.pageOffset = offset;
        this.page = this.data.slice(offset, offset + this.pageSize);
        this.dispatchEvent(new CustomEvent('pagechange', { detail: this.page }));
    }

    handleRowAction(event) {
        this.dispatchEvent(new CustomEvent('rowaction', { detail: event.detail }));
    }

    handleCellChange(event) {
        event.preventDefault();
        event.stopPropagation();
        this.dispatchEvent(new CustomEvent('cellchange', { detail: event.detail }));
    }

    handleSort(event) {
        this.dispatchEvent(new CustomEvent('sort', { detail: event.detail } ));
    }

}