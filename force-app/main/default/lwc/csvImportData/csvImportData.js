import { LightningElement,track,api,wire } from 'lwc';
import {idGenerator,xLabelService} from 'c/xUtils';
import { DateUtils } from "c/utils";
import getImportFieldsDefinition from '@salesforce/apex/CSVImportTemplateHelper.getImportFieldDefinitions';
import getRecordIds from '@salesforce/apex/CSVImportTemplateHelper.getRecordIds';
import importRecords from '@salesforce/apex/CSVImportTemplateHelper.importChildRecord';
import getImportTemplate from '@salesforce/apex/CSVImportTemplateHelper.getImportTemplate';
import getParentUpdatedRecords from '@salesforce/apex/CSVImportTemplateHelper.getParentUpdatedRecords';


export default class CsvImportData extends LightningElement {

    @track data;
    @track importTemplateId;
    @track headers;
    @track childRecords = [];
    @track parentRecords = [];
    @track recordDetails = {};
    @track columns = [];
    @track rowData = [];
    @track nameFieldsWithObject = [];
    @track nameFieldsWithParent = [];
    @track parentFieldsData = [];
    gen = idGenerator();

    
    @api
    showComp(data){
        this.importTemplateId = data.importTemplateId;
        this.data = data.data;
        this._data = data._data;
        this.fieldDefinitions = data.fieldDefinitions ? data.fieldDefinitions : null;
        if(this.importTemplateId){
            this.fetchImportFieldsDefinition();
        }
    }
    fetchImportFieldsDefinition(){
        getImportFieldsDefinition({recordId : this.importTemplateId})
            .then((result) => {
                if(result.targetObjects.length === 0){
                    this.fireNoObjectSelectedEvent(xLabelService.csvNoObjectSelected);
                }else{
                    this.fieldDefinitions = result;
                    this.doFetchRecordDetails();
                }
            })
            .catch((error) => {
                console.error(error);
            })
    }
    fireNoObjectSelectedEvent(message){
        this.dispatchEvent(new CustomEvent('noobject', {detail : {
            message : message
        }}));
    }
    doFetchRecordDetails(){
        this.getRecord();
    }
    async getRecord() {
        let record = await getImportTemplate({ recordId: this.importTemplateId });
        if(record){
            this.recordDetails = record;
            this.doPrepareData();
        }
    }
    doPrepareData(){
        this.childRecords = [];
        this.parentRecords = [];
        this.nameFieldsWithObject = [];
        this.nameFieldsWithParent = [];
        this.parentFieldsData = [];
        let self = this;
        this.data.forEach((record =>{
            let uniqueVal = this.gen.next().value;

            let tempParent = {'attributes': {'type': this.recordDetails.parent}, rowKey : uniqueVal};
            let tempObj = {'attributes': {'type': self._data[0].objectName},rowKey : uniqueVal};
            Object.keys(record).forEach((item => {
                let index = self._data.map(function(item) { return item.header; }).indexOf(item.trim());

                if(index !== -1 && self._data[index].targetField){
                    if(self._data[index].targetObject === this.recordDetails.parent){
                        if(self._data[index].groupBy === 'true'){
                            tempObj[this.recordDetails.parentRelationship] = record[self._data[index].header] === '' ? null : record[self._data[index].header];
                            this.parentFieldsData.push({name : this.recordDetails.parent, field : self._data[index].lookupField, value : record[self._data[index].header],targetField : self._data[index].targetField});
                        }
                        let fieldIndex = self.fieldDefinitions.targetFields[self._data[index].targetObject].map(function(item) { return item.apiName; }).indexOf(self._data[index].targetField);
                        let objName = self.fieldDefinitions.targetFields[self._data[index].targetObject][fieldIndex];
                        if(self._data[index].lookupType === 'External Id'){
                            if(fieldIndex != -1){
                                let apiName = objName.parentPointing.endsWith('__c') ? objName.parentPointing.substring(0,(objName.parentPointing.length - 3)) : objName.parentPointing;
                                let parentReference = {"attributes" : {"type" : objName.parentPointing}};
                                parentReference[self._data[index].lookupField] = record[self._data[index].header];
                                tempParent[apiName] = parentReference;
                                tempParent[item] = record[self._data[index].header] === '' ? null : record[self._data[index].header];
                            }
                        }else if(self._data[index].lookupType === 'Name Field'){
                            this.nameFieldsWithParent.push({name : objName.parentPointing, field : self._data[index].lookupField, value : record[self._data[index].header],targetField : self._data[index].targetField});
                            tempParent[self._data[index].targetField] = record[self._data[index].header] === '' ? null : record[self._data[index].header];
                            tempParent['targetObject'] = objName.parentPointing;
                        }else{
                            tempParent[self._data[index].targetField] = record[self._data[index].header] === '' ? null : record[self._data[index].header];
                        }
                    }else{
                        let fieldIndex = self.fieldDefinitions.targetFields[self._data[index].targetObject].map(function(item) { return item.apiName; }).indexOf(self._data[index].targetField);
                        let objName = self.fieldDefinitions.targetFields[self._data[index].targetObject][fieldIndex];
                        if(self._data[index].lookupType === 'External Id'){
                            if(fieldIndex != -1){
                                let apiName = objName.parentPointing.endsWith('__c') ? objName.parentPointing.substring(0,(objName.parentPointing.length - 3)) : objName.parentPointing;
                                let parentReference = {"attributes" : {"type" : objName.parentPointing}};
                                parentReference[self._data[index].lookupField] = record[self._data[index].header];
                                tempObj[apiName] = parentReference;
                                tempObj[item] = record[self._data[index].header] === '' ? null : record[self._data[index].header];
                            }
                        }else if(self._data[index].lookupType === 'Name Field'){
                            this.nameFieldsWithObject.push({name : objName.parentPointing, field : self._data[index].lookupField, value : record[self._data[index].header],targetField : self._data[index].targetField});
                            tempObj[self._data[index].targetField] = record[self._data[index].header] === '' ? null : record[self._data[index].header];
                            tempObj['targetObject'] = objName.parentPointing;
                        }else{
                            tempObj[self._data[index].targetField] = record[self._data[index].header] === '' ? null : record[self._data[index].header];
                        }
                    }
                }
            }));
            Object.keys(tempObj).length > 0 ? this.childRecords.push(tempObj) : null;
            (Object.keys(tempParent).length > 0 && Object.keys(tempParent).length !== 2)  ? this.parentRecords.push(tempParent) : null;
        })); 

        if((this.nameFieldsWithParent.length > 0 || this.parentRecords.length > 0) && this.childRecords.length > 0 && this.parentFieldsData.length === 0 ){
            this.fireNoObjectSelectedEvent(xLabelService.csvNoGroupByFound);
            return;
        }
        if(this.nameFieldsWithParent.length > 0){
            this.fetchIdsOfRecords(this.nameFieldsWithParent,true);
        }else if(this.parentFieldsData.length > 0 ){
            this.doFetchParentInfo();
        }else{
            if(this.nameFieldsWithObject.length > 0 ){
                this.fetchIdsOfRecords(this.nameFieldsWithObject,false);
            }else{
                this.saveData();
            }
        }
    }
    doFetchParentInfo(){
        if(this.parentFieldsData.length === 0){
            this.parentFieldsData.push({name : this.recordDetails.parent, field : null, value : null,targetField : 'Name'});
        }
        let uniqueArray = Array.from(new Set(this.parentFieldsData.map(JSON.stringify))).map(JSON.parse);
        let self = this;
        let records = this.parentRecords.map(({targetField,targetObject,tempField, ...rest}) => {
            return rest;
        });
        records = this.checkDateValidityIfAny(records);
        records = this.checkBooleanValidity(records);
        getParentUpdatedRecords({recordsToFetch : JSON.stringify(uniqueArray), records : JSON.stringify(records)})
        .then((result) => {
            let errorInChild = true;
            result.data.forEach(value => {
                self.childRecords.forEach(item =>{
                    if(item[self.recordDetails.parentRelationship] === value.name && value.id !== ''){
                        item[self.recordDetails.parentRelationship] = value.id;
                    }else if(item[self.recordDetails.parentRelationship] === value.name && value.message !== ''){
                        item['Error'] = value.message;
                    }
                });
                self.parentRecords.forEach(item =>{
                    if(item['Name'] === value.name && value.message !== ''){
                        errorInChild = false;
                        item['Error'] = value.message;
                    }
                });
            });
            if(!result.hasError){
                if(this.nameFieldsWithObject.length > 0 ){
                    self.fetchIdsOfRecords(this.nameFieldsWithObject,false);
                }else{
                    self.saveData();
                }
            }else{
                this.doFireErrorEvent(errorInChild);
            }
        })
        .catch((error) => {
            this.prepareErrorRecordsWithFieldAccess(error.body);
            return false;
        })
    }
    doFireErrorEvent(errorInChild){
        let cols=[];
        if(errorInChild){
            Object.keys(this.childRecords[0]).forEach(item =>{
                if(item !== 'attributes' && item !== 'rowKey' && item !== 'targetObject'){
                    cols.push({label : item, apiName : item});
                }
            });
        }else{
            Object.keys(this.parentRecords[0]).forEach(item =>{
                if(item !== 'attributes' && item !== 'rowKey' && item !== 'targetObject'){
                    cols.push({label : item, apiName : item});
                }
            });
        }

        this.fireErrorEvent(cols,errorInChild ? this.childRecords : this.parentRecords);
    }
    fireErrorEvent(cols,data){
        this.dispatchEvent(new CustomEvent('error', {detail : {
            columns : cols,
            rowData : data
        }}));
    }
    fetchIdsOfRecords(records,fromParent){
        let uniqueArray = Array.from(new Set(records.map(JSON.stringify))).map(JSON.parse);
        let self = this;
        getRecordIds({recordsToFetch : JSON.stringify(uniqueArray)})
            .then((result) => {
                if(fromParent){
                    self.prepareParentData(result);
                }else{
                    self.prepareChildData(result);
                }
            })
            .catch((error) => {
                console.error(error);
            })
    }
    prepareParentData(result){
        let self = this;
        let hasError = false;
        result.forEach(item => {
            self.parentRecords.forEach(record =>{
                if(record[item.targetField] && record[item.targetField] === item.value && (!item.errorMessage)){
                    record[item.targetField] = item.id;
                }else if(record[item.targetField] && record[item.targetField] === item.value && item.errorMessage){
                    hasError = true;
                    record['Error'] = record['Error'] != undefined ? record['Error'] + ' '+item.errorMessage + ',' : ' '+item.errorMessage +',' ;
                }
            })
        });
        if (!hasError) {
            this.doFetchParentInfo();
        } else {
            self.parentRecords.forEach(record =>{
                if (record['Error'] != undefined) {
                    record['Error'] = record['Error'].endsWith(',') ? record['Error'].substring(0, record['Error'].lastIndexOf(',')) : record['Error'];
                }
            })
            this.doFireErrorEvent(false);
        }
    }
    prepareChildData(result){
        let self = this;
        let hasError = false;
        result.forEach(item => {
            self.childRecords.forEach(record =>{
                if(record[item.targetField] && record[item.targetField] === item.value && (!item.errorMessage)){
                    record[item.targetField] = item.id;
                } else if(record[item.targetField] && record[item.targetField] === item.value && item.errorMessage){
                    hasError = true;
                    record['Error'] = record['Error'] != undefined ? record['Error'] + ' '+item.errorMessage + ',' : ' '+item.errorMessage +',' ;
                }
            })
        });
        if (!hasError) {
            this.saveData();
        } else {
            self.childRecords.forEach(record =>{
                if (record['Error'] != undefined) {
                    record['Error'] = record['Error'].endsWith(',') ? record['Error'].substring(0, record['Error'].lastIndexOf(',')) : record['Error'];
                }
            })
            this.doFireErrorEvent(true);
        }
    }
    saveData(){
        let records = this.childRecords.map(({targetField,targetObject,tempField, ...rest}) => {
            return rest;
        });
        records = this.checkDateValidityIfAny(records);
        records = this.checkBooleanValidity(records);
        importRecords({recordsToImport : JSON.stringify(records)})
            .then((result) => {
                if(result.hasError){
                    this.prepareErrorRecords(result.data);
                }else{
                    this.dispatchEvent(new CustomEvent('save'));
                }
            })  
            .catch((error) =>{
                this.prepareErrorRecordsWithFieldAccess(error.body);
                console.error(error);
            })
    }
    checkDateValidityIfAny(records){
        let self = this;
        records.forEach(item =>{
            Object.keys(item).forEach(inner =>{
                if(self.checkIfValidDate(item[inner])){
                    item[inner] = DateUtils.toTimeZoneAdjustedISOString(new Date(item[inner]));
                }
            })
        })
        return records;
    }
    checkIfValidDate(str) {
        const regexExp = /^\d{2}[.-/]\d{2}[.-/]\d{4}|\d{1}[.-/]\d{2}[.-/]\d{4}$/;
        return regexExp.test(str);
    }
    checkBooleanValidity(records) {
        records.forEach(item =>{
            Object.keys(item).forEach(inner =>{
                if(item[inner] === 'true' || item[inner] === 'True' || item[inner] === 'TRUE'){
                    item[inner] = true;
                } else if (item[inner] === 'false' || item[inner] === 'False' || item[inner] === 'FALSE') {
                    item[inner] = false;
                }
            })
        })
        return records;
    }
    prepareErrorRecords(result){
        result.forEach(value => {
            this.childRecords.forEach(item =>{
                if(item.rowKey === value.name){
                    item['Error'] = value.message;
                }
            });
        });
        this.doFireErrorEvent(true);
    }
    prepareErrorRecordsWithFieldAccess(errorBody){
        this.childRecords.forEach(item =>{
            item['Error'] = errorBody.message;
        });
        this.doFireErrorEvent(true);
    }
}