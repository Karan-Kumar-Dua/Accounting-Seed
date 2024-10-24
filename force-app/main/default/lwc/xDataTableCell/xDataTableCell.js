import {LightningElement, api} from 'lwc';
import { LabelService } from 'c/utils';
export default class XDataTableCell extends LightningElement {
    labels = LabelService;
    @api keyField;
    @api column;
    @api row;
    @api initialData;
    @api childReference;
    isEditMode = false;
    input;
    formatter;
    formattedType;
    previousValue = '';

    get inputType(){
        let inputType;
        switch(this.column.type){
            case 'string' :
                inputType = 'text';
                break;
            case 'boolean':
                inputType = 'checkbox';
                break;
            case 'phone':
                inputType = 'tel';
                break;
            case 'percent':
                inputType = 'number';
                this.formatter = 'percent-fixed';
                break;
            default:
                
        }
        return inputType ? inputType : this.column.type;
    }
    get objName(){
        return this.childReference.split('.')[0];
    }
    get isDifferentInputs(){
        let x = this.inputType;
        return x === 'text' || x === 'date' || x === 'number' || x === 'url' || x === 'encryptedstring' ||
                x === 'tel' || x === 'email'  || x === 'datetime' || x === 'formula';  
    }
    get isCurrency(){
        return this.inputType === 'currency';
    }
    get isTimeInput(){
        return this.inputType === 'time';
    }
    get isPicklist(){
        return this.inputType === 'picklist';
    }
    get isCheckbox(){
        return this.inputType === 'checkbox';
    }
    get isTextArea(){
        return this.inputType === 'textarea' && !this.column.isRichText;
    }
    get isRichTextArea(){
        return this.inputType === 'textarea' && this.column.isRichText;
    }
    get isFormattedText(){
        return this.inputType === 'text' || this.inputType === 'picklist' || this.inputType === 'encryptedstring' 
                || this.inputType === 'multipicklist';
    }
    get isFormattedDate(){
        return this.inputType === 'date';
    }
    get isFormattedNumber(){
        return this.inputType === 'number';
    }
    get isFormattedRichText(){
        return this.inputType === 'textarea';
    }
    get isFormattedPhone(){
        return this.inputType === 'tel';
    }
    get isFormattedEmail(){
        return this.inputType === 'email';
    }
    get isFormattedTime(){
        return this.inputType === 'time';
    }
    get isFormattedDateTime(){
        return this.inputType === 'datetime';
    }
    get isFormattedUrl(){
        return this.inputType === 'url';
    }
    get isReference(){
        return this.inputType === 'reference';
    }
    get isMultiPicklist(){
        return this.inputType === 'multipicklist';
    }
    get isFormulaHyperLink() {
        return this.inputType === 'formula' && this.column.typeAttributes.type === 'HYPERLINK' ? true : false;
    }
    get formulaHyperlinkValue() {
        return this.encodeURILink(this.getLinkSubstring('href='));
    }
    get isFormulaImage() {
        return this.inputType === 'formula' && this.column.typeAttributes.type === 'IMAGE' ? true : false;
    }
    get formulaImageValue() {
        return this.encodeURILink(this.getLinkSubstring('src='));
    }
    getLinkSubstring(separator) {
        let linkVal = this.row[this.column.apiName].split(' ')[1].replace(separator, '');
        return linkVal.substring(1,linkVal.length-1);
    }
    encodeURILink(link) {
        return link.replaceAll('&nbsp;', '').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&apos;', '\'');
    }
    get hyperLinkDisplayedName() {
        return this.getDiplayableName('>','</a');
    }
    get imageDisplayedName() {
        return this.getDiplayableName('" ','alt=');
    }
    getDiplayableName(splitParam, replaceParam) {
        return this.row[this.column.apiName].split(splitParam)[1].replace(replaceParam, '').replaceAll('"','');
    }
    get imageStyle() {
        return 'height: ' + this.column.typeAttributes.height + ' !important;width:' + this.column.typeAttributes.width + ' !important;max-width:none !important';
    }
    get searchObject(){
        return this.column.typeAttributes.referenceObject;
    }
    get referenceLabel(){
        return this.getNestedObject(this.row, this.column.typeAttributes.label.fieldName.split('.'));
    }
    get currencyCode(){
        return this.column.currencyCode ? this.column.currencyCode : this.row['CurrencyIsoCode'];
    }
    get referenceValue(){
       return this.row[this.column.apiName]
           ? '/'+this.row[this.column.apiName]
           : null;
    }
    get referenceValueId(){
        return this.row['Id']
        ? '/'+this.row['Id']
        : null;
    }
    get step(){
        let decimals = (this.column.typeAttributes && this.column.typeAttributes.minimumFractionDigits) ? this.column.typeAttributes.minimumFractionDigits : '1';
        return "0."+ "0".repeat(decimals-1)+"1";
    }
    get outputValuesDecoration(){
        return this.column.type === 'number' || this.column.type === 'currency' ?
            !this.column.updateable ? 'slds-size_3-of-3 slds-truncate floatRight' : 'slds-size_2-of-3 slds-truncate floatRight' :
            !this.column.updateable ? 'slds-size_3-of-3 slds-truncate' : 'slds-size_2-of-3 slds-truncate';
    }
    get timeValue(){
        let duration = this.row[this.column.apiName]
        var milliseconds = parseInt((duration % 1000) / 100),
        seconds = Math.floor((duration / 1000) % 60),
        minutes = Math.floor((duration / (1000 * 60)) % 60),
        hours = Math.floor((duration / (1000 * 60 * 60)) % 24);
    
        hours = (hours < 10) ? "0" + hours : hours;
        minutes = (minutes < 10) ? "0" + minutes : minutes;
        seconds = (seconds < 10) ? "0" + seconds : seconds;
          
        return hours ? hours + ":" + minutes : this.row[this.column.apiName];
    }
    get inEditMode(){
        return this.row['inEditMode'] ? true : this.isEditMode;
    }
    get fieldValue() {
        return this.row[this.column.apiName];
    }
    get truncatedFieldValue(){
        if(this.row[this.column.apiName]){
            return this.row[this.column.apiName].length > 25 ? this.row[this.column.apiName].substring(0,25) + '...' : this.row[this.column.apiName];
        }
        return this.row[this.column.apiName];
    }
    get picklistOptions(){
        let options =[];
        let picklistValues = this.column.picklistValues;
        if(this.column.isDependent){
            picklistValues = this.column.dependentPicklistValues[this.row[this.column.dependentOn]];
        }
        for (let val in picklistValues) {
            options.push({label : val, value :picklistValues[val] });
        }
        return options;
    }
    get selectedValues(){
        let val = this.row[this.column.apiName];
        return val ? val.split(';') : [];
    }
    
    get isReadOnly(){
        return !this.column.updateable;
    }
    get isDirtyCell(){
        return (this.row[this.column.apiName] != this.initialData[this.column.apiName]) && !(this.row[this.column.apiName] === '' && !this.initialData[this.column.apiName]) && (!this.isEditMode)  && (!this.row['inEditMode']) ? 'dirtyCss cellClass' : 'cellClass';
    }
    get editModeItemsCSS(){
        return this.column.isRequired && (!this.row.singleUseRow) ? 'slds-size_3-of-3 displayFlex' : 'slds-size_3-of-3 displayGrid';
    }

    get isHover() {
        return this._isHover;
    }
    set isHover(value) {
        this._isHover = value;
    }

    get iconName() {
        return !this.column.updateable ?
            (this.isHover ? 'utility:lock' : 'utility:sprite') :
            'utility:edit';
    }
    get fieldRequiredOnUI() {
        return this.row.singleUseRow && this.column.isRequired ? true : false;
    }
    get showRequiredSign() {
        return this.row.singleUseRow && this.column.isRequired ? false : this.column.isRequired;
    }
    handleEditClick(evt){
        this.isEditMode = evt.target.iconName === 'utility:edit' ? !this.isEditMode : this.isEditMode;
    }
    handleChange(evt){
        if(this.column.type === 'number' && !(evt.target.value).endsWith('.')){
            let input = this.template.querySelector('lightning-input[data-id="cell-input"]');
            let values = (evt.target.value).split('.');
            if(values.length > 1){
                values[1] = values[1].substring(0,this.column.typeAttributes.minimumFractionDigits);
            }
            input.value = values.join('.');
        }
        //keeping the track of the previous value 
        this.previousValue = evt.target.value;
    }
    handlePicklistChange(evt){
        let value = evt.target ? evt.target.value : this.previousValue;
        let changed = (this.row[this.column.apiName] || value != '') && this.row[this.column.apiName] != value 
        this.fireCellMutationEvt(value,{isPicklistChange :true },changed);         
    }
    handleBlur(evt){
        evt.preventDefault();
        evt.stopImmediatePropagation();
        this.manageEditMode();
        let value = evt.target ? evt.target.value : this.previousValue;
        let changed = (this.row[this.column.apiName] || value != '') && this.row[this.column.apiName] != value 
        this.fireCellMutationEvt(value,evt,changed); 
    }
    handleCheck(evt){
        let changed = this.row[this.column.apiName] != evt.target.checked 
        this.fireCellMutationEvt(evt.target.checked,evt,changed);
        this.manageEditMode();
    }
    fireCellMutationEvt(val,evt,changed){
        const mutation = new CustomEvent('mutation', {
            detail: {
                rowKey: this.row[this.keyField],
                apiName: this.column.apiName,
                value: val,
                label: evt.detail && evt.detail.recordName ? evt.detail.recordName : null,
                changed : changed,
                isPicklistChange : evt.isPicklistChange ? evt.isPicklistChange : false
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(mutation);
    }
    handleSelectionChange(evt){
        this.fireCellMutationEvt(evt.detail ? evt.detail.recordId : null, evt,this.row[this.column.apiName] != (evt.detail ? evt.detail.recordId : null));
    }
    handleInputFocusout(evt){
        this.manageEditMode();
    }
    handleMultiPickChange(evt){
        let tempVal = '';
        let value = JSON.parse(JSON.stringify(evt.target.value));
        
        value.forEach(item => {
            tempVal = tempVal + item + ';';
        })
        this.previousValue = tempVal.substring(0,tempVal.trim().length-1);
        let changed = (this.row[this.column.apiName] || this.previousValue != '') && this.row[this.column.apiName] != this.previousValue;
        this.fireCellMutationEvt(this.previousValue,{isPicklistChange :true },changed);
    }
    getNestedObject = (nestedObj, pathArr) => {
        return pathArr.reduce((obj, key) =>
            (obj && obj[key] !== 'undefined') ? obj[key] : undefined, nestedObj);
    }

    //cell hover iffects
    handleMouseEnter(evt){
        evt.preventDefault();
        evt.stopImmediatePropagation();
        this.isHover = true;
    }

    handleMouseOut(evt){
        evt.preventDefault();
        evt.stopImmediatePropagation();
        this.isHover = false;
        if(this.inputType === 'reference'){
            this.manageEditMode();
        }
    }
    manageEditMode(){
        this.isEditMode = this.row['inEditMode'] ? true : false;
    }
    @api
    reportValidity() {
        let isValid = true;

        let element = this.template.querySelector('lightning-input');
        isValid = element ? this.showValidityError(element) : isValid;

        element = this.template.querySelector('lightning-combobox');
        isValid = element ? this.showValidityError(element) : isValid; 
        
        element = this.template.querySelector('lightning-dual-listbox');
        isValid = element ? this.showValidityError(element) : isValid;

        element = this.template.querySelector('lightning-textarea');
        isValid = element ? this.showValidityError(element) : isValid;
        
        element = this.template.querySelector('lightning-input-rich-text');
        isValid = element ? this.showValidityError(element) : isValid;
        
        element = this.template.querySelector('c-x-custom-currency-cell');
        isValid = element ? element.reportValidity() : isValid;
        
        element = this.template.querySelector('c-x-lookup');
        isValid = element ? element.reportValidity() : isValid;
        
        return isValid;
        
    }
    showValidityError(element) {
        let valid = true;
        if(!element.checkValidity()) {
            valid = false;
        } else {
            element.setCustomValidity('');
        }
        element.reportValidity();
        return valid;
    }
}