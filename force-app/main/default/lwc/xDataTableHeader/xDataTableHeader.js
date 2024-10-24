import {LightningElement, api,track} from 'lwc';
import { LabelService } from 'c/utils';

export default class XDataTableHeader extends LightningElement {
    labels = LabelService;
    @api selectAll = false;
    @api
    get swingAll() {
        return this._swingAll;
    }
    set swingAll(value) {
        this._swingAll = value;
    }

    @api defaultSorting;
    @api columns;
    @api hasDrawerFields;
    @api rowNumberColumn;

     //user can control visibility
     @track errorColumn = true;
     @track checkboxColumn = true;
     @track actionColumn = true;
     @track showSortButton = true;
 
     @api 
     get showSelectedColumns(){
         return undefined;
     }
     set showSelectedColumns(val){
         this.errorColumn = val.errorColumn;
         this.checkboxColumn = val.checkboxColumn;
         this.actionColumn = val.actionColumn;
         this.showSortButton = val.showSortButton;
     }
    _swingAll = false;

    get thStyle(){
        return "width : " + Math.floor(100 / this.columns.length) + '%';
    }

    get iconName(){
        return this.swingAll ? 'utility:chevrondown' : 'utility:chevronright';
    }
    handleSelectAll(evt) {
        this.selectAll = evt.target.checked;
        const select = new CustomEvent('selectall', {
            detail: {
                checked: this.selectAll
            }
        });
        this.dispatchEvent(select);
    }
    handleSwingAll(evt){
        this.swingAll = !this.swingAll;
        const select = new CustomEvent('swingall', {
            detail: {
                swingAll: this.swingAll
            }
        });
        this.dispatchEvent(select);
    }
    get hasReOrderCols(){
        return (this.rowNumberColumn && Object.keys(this.rowNumberColumn).length !== 0);
    }
    @api 
    updateSortOrder(apiName){
        let headerCols = this.template.querySelectorAll('[data-id="header-sorting"]');
        if(headerCols && headerCols.length > 0){
            headerCols.forEach(item => {
                if(item.getApiName() === apiName){
                    item.updateSortOrder();
                }
            })
        }
    }
}