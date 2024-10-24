export default {
    title: "Accounts",
    iconName: "standard:account",
    actions:[
        {
            icon: "utility:edit",
            name: "edit",
            label: "Edit",
            variant: "border-filled",
            alternativeText: "Edit",
            global: true
        },
        {
            icon: "utility:save",
            name: "save",
            label: "Save",
            variant: "border-filled",
            alternativeText: "Save",
            global: true
        },
        {
            icon: "utility:animal_and_nature",
            name: "animals",
            label: "Custom Animal Action",
            variant: "border-filled",
            alternativeText: "Custom Animal Button",
            global: false
        },
        {
            icon: "utility:download",
            name: "csv",
            label: "CSV",
            variant: "border-filled",
            alternativeText: "CSV",
            global: true
        }
    ],
    columns:[
        {
            label: "Name",
            fieldName: "Name",
            type: "text"
        },
        {
            label: "Type",
            fieldName: "Type",
            type: "text"
        },
        {
            label: "Industry",
            fieldName: "Industry",
            type: "text"
        }
    ],
    drawer:[
        {
            label: "Number of Employees",
            fieldName: "NumberOfEmployees",
            type: "number"
        }
    ],
    mockData: [
        {
            "Id": "0010R00001NTQiAQAX",
            "Name": "Edge Communications",
            "Industry": "Electronics",
            "NumberOfEmployees": 1000,
            "Type": "Prospect"
        },
        {
            "Id": "0010R00001NTQiBQAX",
            "Name": "Burlington Textiles Corp of America",
            "Industry": "Apparel",
            "NumberOfEmployees": 9000,
            "Type": "Customer"
        },
        {
            "Id": "0010R00001NTQiCQAX",
            "Name": "Pyramid Construction Inc.",
            "Industry": "Construction",
            "NumberOfEmployees": 2680,
            "Type": "Prospect"
        },
        {
            "Id": "0010R00001NTQiDQAX",
            "Name": "Dickenson plc",
            "Industry": "Consulting",
            "NumberOfEmployees": 120,
            "Type": "Customer"
        },
        {
            "Id": "0010R00001NTQiEQAX",
            "Name": "Grand Hotels & Resorts Ltd",
            "Industry": "Hospitality",
            "NumberOfEmployees": 5600,
            "Type": "Customer"
        },
        {
            "Id": "0010R00001NTQiFQAX",
            "Name": "United Oil & Gas Corp.",
            "Industry": "Energy",
            "NumberOfEmployees": 145000,
            "Type": "Prospect"
        },
        {
            "Id": "0010R00001NTQiGQAX",
            "Name": "Express Logistics and Transport",
            "Industry": "Transportation",
            "NumberOfEmployees": 12300,
            "Type": "Customer"
        },
        {
            "Id": "0010R00001NTQiHQAX",
            "Name": "University of Arizona",
            "Industry": "Education",
            "NumberOfEmployees": 39000,
            "Type": "Customer"
        },
        {
            "Id": "0010R00001NTQiIQAX",
            "Name": "United Oil & Gas, UK",
            "Industry": "Energy",
            "NumberOfEmployees": 24000,
            "Type": "Prospect"
        },
        {
            "Id": "0010R00001NTQiJQAX",
            "Name": "United Oil & Gas, Singapore",
            "Industry": "Energy",
            "NumberOfEmployees": 3000,
            "Type": "Prospect"
        }
    ]



}