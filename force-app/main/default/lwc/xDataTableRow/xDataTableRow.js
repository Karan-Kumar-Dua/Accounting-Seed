import {LightningElement, api,track} from 'lwc';
import { LabelService } from 'c/utils'; 
import Labels from './labels';

export default class XDataTableRow extends LightningElement {

    labels = {...Labels, ...LabelService};
    @api keyField;
    @api row;
    @api columns;
    @api drawer;
    @api initialData;
    @api childReference;
    @api hasDrawerFields;
    @api rowLevelAction;
    @api rowNumberColumn;

    //user can control visibility
    @track errorColumn = true;
    @track checkboxColumn = true;
    @track actionColumn = true;

    @api 
    get showSelectedColumns(){
        return undefined;
    }
    set showSelectedColumns(val){
        this.errorColumn = val.errorColumn;
        this.checkboxColumn = val.checkboxColumn;
        this.actionColumn = val.actionColumn;
    }

    @api select(checked){
        const selectList = this.template.querySelectorAll('[data-id^="_row_selected"]');
        for (const checkBox of selectList) {
            checkBox.checked = checked;
        }
    }
    get orderValue(){
        return this.row[this.rowNumberColumn.apiName];
    }
    handleChecked(evt){
        this.fireMutationEvent('_selected',!this.row._selected);
    }
    handleDrawerSwing(evt){
        this.fireMutationEvent('_drawer',!this.row._drawer);
    }
    fireMutationEvent(apiName, value){
        const mutation = new CustomEvent('mutation', {
            detail: {
                rowKey: this.row[this.keyField],
                apiName: apiName,
                value: value
            }
        });
        this.dispatchEvent(mutation);
    }
    get hasReOrderCols(){
        return (this.rowNumberColumn && Object.keys(this.rowNumberColumn).length !== 0);
    }
}