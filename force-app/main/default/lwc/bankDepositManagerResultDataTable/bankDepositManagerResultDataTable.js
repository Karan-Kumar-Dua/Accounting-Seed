import { LightningElement, api,track } from 'lwc';

export default class BankDepositManagerResultDataTable extends LightningElement {
    @track _columns;
    @api result = [];
    @api selectedRowIds;
    @api totalRecordsCount;
    @api hasMoreRecordsToLoad;
    @track visibledata;
    visibleRows = 2
    pendingAction='';
    startRowIndex = 0;
    moveToPageWhenLoadCompletes = 1;

    @api 
    get columns(){
        return this._columns;
    }

   
    set columns(value){
        if(value && value.length > 0){
            this._columns = value
            if(this.result && this.result.length > 0){
                this.handlePendingActions(value);
                this.visibledata = this.getVisibleData();
            }
        }
    }

    @api 
    get recordToDisplay(){
        return this.result
    }

    set recordToDisplay(value){ 
        if(value){
            this.result = value
            if(value.length > 0){
                this.handlePendingActions(value);
                this.visibledata = this.getVisibleData();
            } else {
                this.visibledata = []
            }
        }
    }

    @api
    moveToPage(offset){
        this.handlePageChange({detail : offset});
    }

    get hasRecordsForPagination(){
        return this.result ? this.result.length > this.visibleRows : false;
        
    }
    
    get totalNumberOfRecords(){
        if(!this.hasMoreRecordsToLoad){
            return this.result && this.result.length || 0;
        }else{
            return this.totalRecordsCount;
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
            startIndex = this.startRowIndex > this.result.length ? this.result.length - this.visibleRows : this.startRowIndex  
        } else {
            endIndex = this.result.length;
            startIndex = this.result.length > (this.startRowIndex + this.visibleRows) ?  this.startRowIndex + this.visibleRows : this.startRowIndex;
        }
        if(startIndex >= this.totalNumberOfRecords && endIndex >= this.totalNumberOfRecords){
            return this.result.slice(startIndex-this.visibleRows,startIndex);
        }
        return this.result.slice(startIndex, endIndex);
    }

    handleSelectedRows(event) {
        try{
            if(event.detail.config.action == 'deselectAllRows'){
                event.detail.delectedRows = this.getDeselectedRowIds()
            }
            const rowSelection = new CustomEvent('rowselect', {
                detail: event.detail
            });
            this.dispatchEvent(rowSelection)  
        }catch(error){
            this.showErrorNotification(JSON.stringify(error?.body?.message), this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
        }
    }
   
    getDeselectedRowIds(){
       return this.visibledata.map(row => row.Id)
    }

    handlePageChange({ detail : offset}) {
        if(this.result && this.result.length <= offset && this.result.length < this.totalNumberOfRecords){
            this.pendingAction = 'pageChange';
            this.moveToPageWhenLoadCompletes = offset;
            this.fireLoadMoreEvent(offset);
        }else if(offset <= this.totalNumberOfRecords){
            this.template.querySelector('lightning-datatable').selectedRows = this.selectedRowIds
            this.startRowIndex = offset;
            this.visibledata = this.result.slice(offset, offset + this.visibleRows);            
        }
    }

    fireLoadMoreEvent(offset){
        this.dispatchEvent(new CustomEvent('loadmore', { detail: {offset : offset} }));
    }

}