export default class CsvParser {

    constructor(papaResource){
        this.papa = papaResource;
    }

    papa;

    jsonToCsv(data){
        return this.papa.unparse(data);
    }
    jsonToCsvUnparse(data){
        return this.papa.unparse({
            "fields" : data.columns,
            "data" : data.data
        });
    }
    csvToJson(data){
        return this.papa.parse(data);
    }

}