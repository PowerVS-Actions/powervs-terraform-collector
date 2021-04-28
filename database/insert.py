#!/usr/bin/python3

import os
import psycopg2
from datetime import datetime

from configparser import ConfigParser

def config(filename='database.ini', section='postgresql'):
    # create a parser
    parser = ConfigParser()
    # read config file
    parser.read(filename)
    # get section, default to postgresql
    db = {}
    if parser.has_section(section):
        params = parser.items(section)
        for param in params:
            db[param[0]] = param[1]
    else:
        raise Exception('Section {0} not found in the {1} file'.format(section, filename))

    return db
    
def drop_view(view_name):
    sql = "DROP VIEW IF EXISTS " + view_name + ";"

    conn = None

    try:
        # read database configuration
        params = config()
        # connect to the PostgreSQL database
        conn = psycopg2.connect(**params)
        # create a new cursor
        cur = conn.cursor()
        # execute the INSERT statement
        cur.execute(sql)
        # get the powervs_id back
        conn.commit()
        # close communication with the database
        cur.close()
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()

def create_view(view_name, source_table):

    sql="CREATE VIEW " + view_name + " AS (SELECT * FROM " + source_table + ");"
    conn = None

    try:
        # read database configuration
        params = config()
        # connect to the PostgreSQL database
        conn = psycopg2.connect(**params)
        # create a new cursor
        cur = conn.cursor()
        # execute the INSERT statement
        cur.execute(sql)
        # get the powervs_id back
        conn.commit()
        # close communication with the database
        cur.close()
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()
            
def create_table(table_name):
    
    sql="CREATE TABLE " + table_name + " AS (SELECT * FROM powervs_all) with no data;"
    conn = None

    try:
        # read database configuration
        params = config()
        # connect to the PostgreSQL database
        conn = psycopg2.connect(**params)
        # create a new cursor
        cur = conn.cursor()
        # execute the INSERT statement
        cur.execute(sql)
        # get the powervs_id back
        conn.commit()
        # close communication with the database
        cur.close()
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()


def insert_data(table,date,time_utc,powervsid,ibmcloud_account,powervs_name,dc_zone,instances,processors,memory,storage_tier1,storage_tier3):

    sql = "INSERT INTO " + table + " (date,time_utc,powervsid,ibmcloud_account,powervs_name,dc_zone,instances,processors,memory,storage_tier1,storage_tier3) \
    VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING powervsid;"
    conn = None
    powervs_id = None
    try:
        # read database configuration
        params = config()
        # connect to the PostgreSQL database
        conn = psycopg2.connect(**params)
        # create a new cursor
        cur = conn.cursor()
        # execute the INSERT statement
        cur.execute(sql, (date,time_utc,powervsid,ibmcloud_account,powervs_name,dc_zone,instances,processors,memory,storage_tier1,storage_tier3,))
        # get the powervs_id back
        powervs_id = cur.fetchone()[0]
        # commit the changes to the database
        conn.commit()
        # close communication with the database
        cur.close()
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()
    return powervs_id

if __name__ == '__main__':

    if os.path.exists("all.csv"):
        today = datetime.today().strftime('%Y%m%d_%H%M%S')
        new_table = "pvsdata_" + today
        create_table(new_table)

        with open("all.csv") as f:
            content = f.readlines()
            pvs_data = [x.strip() for x in content]

            for data in pvs_data:
                # ds: data splited
                ds = data.split(",")
                insert_data(new_table,ds[0],ds[1],ds[3],ds[2],ds[4],ds[5],ds[6],ds[7],ds[8],ds[9],ds[10])
        drop_view("pvsdata_all_resources")
        create_view("pvsdata_all_resources",new_table)
    else:
        print ("ERROR: could not locate the required .csv file")
        exit(1)
