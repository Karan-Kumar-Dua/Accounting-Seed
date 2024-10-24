import getColumns from '@salesforce/apex/FieldSetHelper.getColumns';
import getQueryString from '@salesforce/apex/FieldSetHelper.getQueryString';
import getCountQueryString from '@salesforce/apex/FieldSetHelper.getCountQueryString';

export const getFieldSetColumns = function(fsRequest) {
    return getColumns({request : fsRequest});
}
export const getQueryStr = function(fsRequest){
    return getQueryString({request : fsRequest});        
}
export const getCountQueryStr = function(fsRequest){
    return getCountQueryString({request : fsRequest});        
}