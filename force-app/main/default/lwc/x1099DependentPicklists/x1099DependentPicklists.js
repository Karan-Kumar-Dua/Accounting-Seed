import { LightningElement, api, track, wire } from 'lwc';
import getFormTypes from '@salesforce/apex/X1099InfoHelper.getFormTypes';
import getFormCategories from '@salesforce/apex/X1099InfoHelper.getFormCategoriesByFormType';
import { LabelService } from 'c/utils';

const NONE = { label: LabelService.commonNoneOption, value: '' };

export default class X1099DependentPicklists extends LightningElement {

    @api 
    get formTypeValue() {
        return this.selectedForm1099Type;
    }
    set formTypeValue(val) {
        if (!this.selectedForm1099Type || this.selectedForm1099Type === NONE.value) {
            this.selectedForm1099Type = val ? val : NONE.value;
        }
    }
    @api
    get formBoxValue() {
        return this.selectedForm1099Box;
    }
    set formBoxValue(val) {
        if (!this.selectedForm1099Box || this.selectedForm1099Box === NONE.value) {
            this.selectedForm1099Box = val ? val : NONE.value;
        }
    }

    @api formTypeInputLabel = LabelService.commonForm1099Type;
    @api boxInputLabel = LabelService.commonForm1099Box;

    form1099TypeOpts = [NONE];
    form1099BoxOpts = [NONE];
    @track selectedForm1099Type = NONE.value;
    selectedForm1099Box = NONE.value;
    isLoadingform1099TypeOpts = true;
    isLoadingForm1099BoxOpts = false;

    @wire (getFormTypes, { effectiveYear: new Date().getFullYear() }) 
    formTypes({ data }) {
        this.form1099TypeOpts = this.transformPickOpts(data);
        this.isLoadingform1099TypeOpts = false;
    }

    @wire (getFormCategories, { formTypeId: '$selectedForm1099Type' }) 
    formBoxes({ data }) {
        this.form1099BoxOpts = this.transformPickOpts(data);
        this.isLoadingForm1099BoxOpts = false;
    }

    get isForm1099BoxInputDisabled() {
        return this.selectedForm1099Type ? false : true;
    }

    transformPickOpts(xs = []) {
        let opts = xs.map(x => ({label: x.Label, value: x.Id}));
        opts.unshift(NONE);
        return opts;
    }

    handleTypeChange(event) {
        this.preventBubble(event);
        this.selectedForm1099Type = event.detail.value || NONE.value;
        this.selectedForm1099Box = NONE.value;
        this.form1099BoxOpts = [NONE];
        this.isLoadingForm1099BoxOpts = true;
        this.dispatchChange();
    }

    handleBoxChange(event) {
        this.preventBubble(event);
        this.selectedForm1099Box = event.detail.value || NONE.value;
        this.dispatchChange();
    }

    preventBubble(event) {
        event.preventDefault();
        event.stopPropagation();
    }

    dispatchChange() {
        this.dispatchEvent(new CustomEvent('change', { detail: {
            value: {
                type: this.selectedForm1099Type || null,
                box: this.selectedForm1099Box || null
            }
        }}));
    }

}