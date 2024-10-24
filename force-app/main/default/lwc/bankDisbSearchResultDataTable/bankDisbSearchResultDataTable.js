import { LightningElement, track, api } from 'lwc';
import { LabelService } from "c/utils";
import ERR_IN_SEARCH_TABLE from '@salesforce/label/c.ERR_IN_SEARCH_TABLE';

export default class BankDisbSearchResultDataTable extends LightningElement {
    labelData = {...LabelService, ERR_IN_SEARCH_TABLE};

    @api result;
    @api columns;
    @api totalRecordsCount;
    @api hasMoreRecordsToLoad = false;
    @track visibledata;
    @api msgIfNoRecordsToDisplay;
    detailRecordName;
    detailRecordId; 
    isModalOpen = false;
    visibleRows = 10;
    startRowIndex = 0;
    pendingAction='';
    moveToPageWhenLoadCompletes = 1;

    @api 
    get tableData(){
        return this.result;
    }

    @api
    moveToPage(offset){
        this.handlePageChange({detail : offset}, false);
    }
    
    get totalNumberOfRecords(){
        if(!this.hasMoreRecordsToLoad){
            console.log('has more records to load ',result.length)
            return this.result && this.result.length || 0;
        }else{
            console.log('total record count in getter ',this.totalRecordsCount)
            return this.totalRecordsCount;
        }
    }

    get hasRecordsForPagination(){
        return this.result ? this.result.length > this.visibleRows : false;
    }

    set tableData(value){
        if(value){
            this.handlePendingActions(value);
            this.visibledata = this.getVisibleData();
        }
    }

    handlePendingActions(value){
        if(value.length > 0 && this.result.length === this.totalRecordsCount){
            if(this.pendingAction === 'pageChange'){
                this.startRowIndex = this.moveToPageWhenLoadCompletes;
                this.visibledata = this.result.slice(this.startRowIndex, this.startRowIndex + this.visibleRows);
            }
            this.pendingAction = '';
            this.moveToPageWhenLoadCompletes = 1;
        }
    }

    getVisibleData() {
        let endIndex;
        let startIndex;
        if (this.hasRecordsForPagination) {
            endIndex = this.startRowIndex + this.visibleRows;
            startIndex = this.startRowIndex;     
        } else {
            endIndex = this.result.length;
            startIndex = this.result.length > (this.startRowIndex + this.visibleRows) ?  this.startRowIndex + this.visibleRows : this.startRowIndex;
        }
        if(startIndex >= this.totalNumberOfRecords && endIndex >= this.totalNumberOfRecords){
            return this.result.slice(startIndex-this.visibleRows,startIndex);
        }
        return this.result.slice(startIndex, endIndex);
    }

    @api
    getDatatable() {
        return this.refs.stdtable;
    }

    getSelectedRows(evt) {
        const rowSelection = new CustomEvent('rowselect', {
            detail: {
               selectRows: evt.detail.selectedRows
            },
        });
        this.dispatchEvent(rowSelection);
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'view') {
            this.detailRecordId = row.objId;
            this.detailRecordName = row.name;
            this.isModalOpen = true;
        }
    }

    closeModal(event){
        this.isModalOpen = event.detail;
    } 

    handlePageChange({ detail : offset}) {
    
        if(this.result && this.result.length <= offset && this.result.length < this.totalNumberOfRecords){
            this.pendingAction = 'pageChange';
            this.moveToPageWhenLoadCompletes = offset;
            this.fireLoadMoreEvent(offset);
        }else if(offset <= this.totalNumberOfRecords){
            this.startRowIndex = offset;
            this.visibledata = this.result.slice(offset, offset + this.visibleRows);
            
        }
    }

    fireLoadMoreEvent(offset){
        this.dispatchEvent(new CustomEvent('loadmore', { detail: {offset : offset} }));
    }
}