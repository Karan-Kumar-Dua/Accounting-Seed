import { LightningElement,api,track } from 'lwc';
import { LabelService } from 'c/utils'; 

export default class XDataTableHeaderColumn extends LightningElement {
    labels = LabelService;
    @track sortOrder = "ASC";
    @api column;
    @api showSortButton;
    iconName = 'utility:sprite';
    
    @api 
    get defaultSorting(){
        this.sortOrder;
    }
    set defaultSorting(val){
        if(val){
            this.sortOrder = val;
        }
    }
    handleColumnSorting(evt){
        this.sortOrder = this.sortOrder === 'ASC' ? 'DESC' : 'ASC';
        const columnSort = new CustomEvent('columnsort',{
            detail :{
                apiName : this.column.apiName,
                sortOrder : this.sortOrder,
                fieldType : this.column.type,
                refrenceField : this.column.type === 'reference' ? this.column.typeAttributes.label.fieldName.split('.')[0] : null
            },
            bubbles:true,
            composed:true
        });
        this.dispatchEvent(columnSort);
        this.refreshIconName();
    }

    refreshIconName(){
        this.iconName = this.defaultSorting === 'ASC' ?  'utility:arrowup' : 'utility:arrowdown';
    }
    handleMouseEnter(){
        this.refreshIconName();
    }
    handleMouseLeave(){
        this.iconName = 'utility:sprite';
    }
    @api
    updateSortOrder(){
        this.sortOrder = this.sortOrder === 'ASC' ? 'DESC' : 'ASC';
    }
    @api
    getApiName(){
        return this.column.apiName;
    }
}