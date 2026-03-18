"""
Microvellum Database Web Application - FastAPI Backend
Provides API endpoints for project/work order management and schema visualization
Production plan queries use corrected LinkID joins with LTRIM/RTRIM
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
import pyodbc
from typing import List, Dict, Any, Optional
from datetime import datetime
import re
import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv(override=True)

app = FastAPI(title="Microvellum Database API", version="2.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database configuration from environment variables
DB_CONFIG = {
    'server': os.getenv('DB_SERVER'),
    'database': os.getenv('DB_DATABASE'),
    'driver': os.getenv('DB_DRIVER', 'ODBC Driver 18 for SQL Server'),
    'trusted_connection': os.getenv('DB_TRUSTED_CONNECTION', 'yes'),
    'use_windows_auth': os.getenv('DB_USE_WINDOWS_AUTH', 'true').lower() == 'true',
    'username': os.getenv('DB_USERNAME', ''),
    'password': os.getenv('DB_PASSWORD', ''),
}

def get_connection():
    """Create and return database connection"""
    conn_str = (
        f"DRIVER={{{DB_CONFIG['driver']}}};"
        f"SERVER={DB_CONFIG['server']};"
        f"DATABASE={DB_CONFIG['database']};"
    )
    if DB_CONFIG['use_windows_auth']:
        conn_str += f"Trusted_Connection={DB_CONFIG['trusted_connection']};"
    else:
        conn_str += f"UID={DB_CONFIG['username']};PWD={DB_CONFIG['password']};"
    conn_str += "TrustServerCertificate=yes;"
    return pyodbc.connect(conn_str)

# Pydantic models
class Project(BaseModel):
    project_number: str
    project_name: str
    work_order_count: int

class WorkOrder(BaseModel):
    schema_name: str
    project_number: str
    drawing_number: str
    work_order_name: str
    table_count: int
    total_rows: int
    products_count: int
    parts_count: int

class TableInfo(BaseModel):
    name: str
    row_count: int
    column_count: int

class QueryRequest(BaseModel):
    query: str

class SheetTrackingRequest(BaseModel):
    schema_name: str
    scrapped_sheet_number: Optional[int] = None
    scrapped_station: Optional[int] = None

@app.get("/")
def root():
    """API root endpoint"""
    return {
        "message": "Microvellum Database API",
        "version": "2.0.0",
        "endpoints": [
            "/projects",
            "/projects/{project_number}/workorders",
            "/schema/{schema_name}/info",
            "/schema/{schema_name}/tables",
            "/schema/{schema_name}/relationships",
            "/schema/{schema_name}/workorder-details",
            "/query",
            "/sheet-tracking"
        ]
    }

@app.get("/projects", response_model=List[Project])
def get_projects():
    """Get all unique projects from migrated schemas"""
    try:
        conn = get_connection()
        cursor = conn.cursor()

        # Get all schemas matching P{project}_{drawing} pattern
        query = """
        SELECT DISTINCT TABLE_SCHEMA
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA LIKE 'P%_%'
        AND TABLE_TYPE = 'BASE TABLE'
        """

        cursor.execute(query)
        schemas = [row[0] for row in cursor.fetchall()]

        # Extract unique projects
        projects_dict = {}
        for schema in schemas:
            # Extract project number (P1987_D018 -> 1987)
            match = re.match(r'P(\d+)_', schema)
            if match:
                project_num = match.group(1)
                if project_num not in projects_dict:
                    projects_dict[project_num] = {
                        'project_number': project_num,
                        'schemas': []
                    }
                projects_dict[project_num]['schemas'].append(schema)

        # Get additional project info
        projects = []
        for proj_num, proj_data in projects_dict.items():
            # Get project name from first Products table
            first_schema = proj_data['schemas'][0]
            try:
                name_query = f"""
                SELECT TOP 1 WorkOrderName
                FROM [{first_schema}].Products
                """
                cursor.execute(name_query)
                result = cursor.fetchone()
                project_name = result[0] if result else f"Project {proj_num}"
            except:
                project_name = f"Project {proj_num}"

            projects.append(Project(
                project_number=proj_num,
                project_name=project_name,
                work_order_count=len(proj_data['schemas'])
            ))

        conn.close()

        # Sort by project number
        projects.sort(key=lambda x: int(x.project_number))

        return projects
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/projects/{project_number}/workorders", response_model=List[WorkOrder])
def get_workorders(project_number: str):
    """Get all work orders (schemas) for a specific project"""
    try:
        conn = get_connection()
        cursor = conn.cursor()

        # Get all schemas for this project
        query = f"""
        SELECT DISTINCT TABLE_SCHEMA
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA LIKE 'P{project_number}_%'
        AND TABLE_TYPE = 'BASE TABLE'
        ORDER BY TABLE_SCHEMA
        """

        cursor.execute(query)
        schemas = [row[0] for row in cursor.fetchall()]

        workorders = []
        for schema in schemas:
            # Extract drawing number (P1987_D018 -> D018)
            match = re.match(r'P\d+_(D\d+)', schema)
            drawing = match.group(1) if match else "Unknown"

            # Get work order name from Products
            try:
                name_query = f"SELECT TOP 1 WorkOrderName FROM [{schema}].Products"
                cursor.execute(name_query)
                result = cursor.fetchone()
                wo_name = result[0] if result else schema
            except:
                wo_name = schema

            # Get table count
            table_query = f"""
            SELECT COUNT(DISTINCT TABLE_NAME)
            FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = '{schema}'
            AND TABLE_TYPE = 'BASE TABLE'
            """
            cursor.execute(table_query)
            table_count = cursor.fetchone()[0]

            # Get Products count
            try:
                prod_query = f"SELECT COUNT(*) FROM [{schema}].Products"
                cursor.execute(prod_query)
                products_count = cursor.fetchone()[0]
            except:
                products_count = 0

            # Get Parts count
            try:
                parts_query = f"SELECT COUNT(*) FROM [{schema}].Parts"
                cursor.execute(parts_query)
                parts_count = cursor.fetchone()[0]
            except:
                parts_count = 0

            workorders.append(WorkOrder(
                schema_name=schema,
                project_number=project_number,
                drawing_number=drawing,
                work_order_name=wo_name,
                table_count=table_count,
                total_rows=products_count + parts_count,
                products_count=products_count,
                parts_count=parts_count
            ))

        conn.close()
        return workorders
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/schema/{schema_name}/info")
def get_schema_info(schema_name: str):
    """Get detailed information about a specific schema"""
    try:
        conn = get_connection()
        cursor = conn.cursor()

        # Get all tables with row counts
        tables = []
        table_query = f"""
        SELECT TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = ?
        AND TABLE_TYPE = 'BASE TABLE'
        ORDER BY TABLE_NAME
        """

        cursor.execute(table_query, schema_name)
        table_names = [row[0] for row in cursor.fetchall()]

        total_rows = 0
        for table in table_names:
            # Get row count
            count_query = f"SELECT COUNT(*) FROM [{schema_name}].[{table}]"
            cursor.execute(count_query)
            row_count = cursor.fetchone()[0]

            # Get column count
            col_query = f"""
            SELECT COUNT(*)
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
            """
            cursor.execute(col_query, schema_name, table)
            col_count = cursor.fetchone()[0]

            tables.append({
                'name': table,
                'row_count': row_count,
                'column_count': col_count
            })
            total_rows += row_count

        conn.close()

        return {
            'schema_name': schema_name,
            'table_count': len(tables),
            'total_rows': total_rows,
            'tables': tables
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/schema/{schema_name}/tables")
def get_schema_tables(schema_name: str):
    """Get all tables in a schema with detailed information"""
    try:
        conn = get_connection()
        cursor = conn.cursor()

        query = f"""
        SELECT
            t.TABLE_NAME,
            COUNT(c.COLUMN_NAME) as ColumnCount
        FROM INFORMATION_SCHEMA.TABLES t
        LEFT JOIN INFORMATION_SCHEMA.COLUMNS c
            ON t.TABLE_SCHEMA = c.TABLE_SCHEMA
            AND t.TABLE_NAME = c.TABLE_NAME
        WHERE t.TABLE_SCHEMA = ?
        AND t.TABLE_TYPE = 'BASE TABLE'
        GROUP BY t.TABLE_NAME
        ORDER BY t.TABLE_NAME
        """

        cursor.execute(query, schema_name)

        tables = []
        for row in cursor.fetchall():
            table_name = row[0]
            col_count = row[1]

            # Get row count
            count_query = f"SELECT COUNT(*) FROM [{schema_name}].[{table_name}]"
            cursor.execute(count_query)
            row_count = cursor.fetchone()[0]

            tables.append({
                'name': table_name,
                'row_count': row_count,
                'column_count': col_count
            })

        conn.close()
        return {'tables': tables}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/schema/{schema_name}/relationships")
def get_schema_relationships(schema_name: str):
    """Get all relationships (LinkID columns) in a schema"""
    try:
        conn = get_connection()
        cursor = conn.cursor()

        query = f"""
        SELECT
            TABLE_NAME,
            COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = ?
        AND COLUMN_NAME LIKE 'LinkID%'
        ORDER BY TABLE_NAME, COLUMN_NAME
        """

        cursor.execute(query, schema_name)

        relationships = []
        for row in cursor.fetchall():
            table = row[0]
            column = row[1]

            # Infer target table
            target_map = {
                'LinkIDWorkOrder': 'WorkOrder',
                'LinkIDProduct': 'Products',
                'LinkIDPart': 'Parts',
                'LinkIDProcessingStation': 'ProcessingStation',
                'LinkIDWorkOrderBatch': 'WorkOrderBatches',
                'LinkIDRoute': 'Routes',
                'LinkIDPlacedSheet': 'PlacedSheets',
                'LinkIDMaterial': 'Material',
                'LinkIDCategory': 'Category',
            }

            target = target_map.get(column, column.replace('LinkID', ''))

            relationships.append({
                'from_table': table,
                'from_column': column,
                'to_table': target,
                'relationship_type': 'foreign_key'
            })

        conn.close()
        return {'relationships': relationships}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/schema/{schema_name}/workorder-details")
def get_workorder_details(schema_name: str):
    """
    Production plan: summary metrics + per-sheet detail.
    Uses corrected LinkID joins with LTRIM/RTRIM.
    Works with both schema-specific tables and dbo.
    """
    try:
        conn = get_connection()
        cursor = conn.cursor()

        # Detect which tables exist in this schema
        cursor.execute("""
            SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = ? AND TABLE_TYPE = 'BASE TABLE'
        """, schema_name)
        available_tables = {row[0] for row in cursor.fetchall()}

        has_drills_h = 'DrillsHorizontal' in available_tables
        has_drills_v = 'DrillsVertical' in available_tables
        has_edgebanding = 'Edgebanding' in available_tables
        has_routes = 'Routes' in available_tables

        # Detect which columns exist in Parts table
        cursor.execute("""
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'Parts'
        """, schema_name)
        parts_columns = {row[0] for row in cursor.fetchall()}

        has_linkid_product = 'LinkIDProduct' in parts_columns
        has_face6barcode = 'Face6Barcode' in parts_columns
        has_comments = 'Comments' in parts_columns
        has_material_name = 'MaterialName' in parts_columns

        # ================================================================
        # QUERY 1: Production Plan Summary (SDF-style)
        # One row per WorkOrderBatch x ProcessingStation
        # ================================================================

        # Build conditional P2P subquery
        if has_face6barcode:
            p2p_subquery = f"""
        LEFT JOIN (
            SELECT LinkIDWorkOrder, COUNT(Quantity) AS Qty
            FROM [{schema_name}].Parts
            WHERE LEN(LTRIM(RTRIM(ISNULL(Face6Barcode, '')))) > 0
            GROUP BY LinkIDWorkOrder
        ) P2P ON OpRe.LinkIDWorkOrder = P2P.LinkIDWorkOrder"""
            p2p_select = "P2P.Qty"
        else:
            p2p_subquery = ""
            p2p_select = "NULL"

        # Build conditional Miter subquery
        if has_comments:
            miter_subquery = f"""
        LEFT JOIN (
            SELECT LinkIDWorkOrder, COUNT(Quantity) AS Qty
            FROM [{schema_name}].Parts
            WHERE Comments LIKE '%@%'
            GROUP BY LinkIDWorkOrder
        ) Miter ON OpRe.LinkIDWorkOrder = Miter.LinkIDWorkOrder"""
            miter_select = "Miter.Qty"
        else:
            miter_subquery = ""
            miter_select = "NULL"

        # Build conditional Edgebanding subquery
        if has_edgebanding:
            edge_subquery = f"""
        LEFT JOIN (
            SELECT SUM(CAST([Edgebanding].[Quantity] AS FLOAT)) * 0.00105 AS Linft,
                   [Edgebanding].[LinkIDWorkOrder]
            FROM [{schema_name}].Edgebanding
            GROUP BY [Edgebanding].[LinkIDWorkOrder]
        ) Edgeing ON OpRe.LinkIDWorkOrder = Edgeing.LinkIDWorkOrder"""
            edge_select = "ROUND(Edgeing.Linft, 0)"
            edge_hours_select = "ROUND(ISNULL(Edgeing.Linft, 0) * 2.8 / 60, 2)"
        else:
            edge_subquery = ""
            edge_select = "NULL"
            edge_hours_select = "0"

        summary_query = f"""
        SELECT
            CASE WHEN OpRe.LinkIDProcessingStation = '21BMOJSH9M90'
                 THEN Sheets.[count] END                        AS NestSht,
            CASE WHEN OpRe.LinkIDProcessingStation = '21BMOJSH9M90'
                 THEN OpRe.OptimizedQuantity END                AS NestPrts,
            CASE WHEN OpRe.LinkIDProcessingStation IN ('1966O1PHUNP10','1966O9J0UOZ10')
                 THEN Sheets.[count] END                        AS PnlSht,
            CASE WHEN OpRe.LinkIDProcessingStation IN ('1966O1PHUNP10','1966O9J0UOZ10')
                 THEN OpRe.OptimizedQuantity END                AS PnlPrts,
            {edge_select}                                       AS Edge,
            {p2p_select}                                        AS P2P,
            {miter_select}                                      AS Miter,
            Solid.Qty                                           AS Solid,
            Product.Product                                     AS Product,
            Part.Parts                                          AS TtlPrts,
            CASE WHEN OpRe.LinkIDProcessingStation = '21BMOJSH9M90'
                 THEN ROUND(OpRe.OptimizedQuantity * 9.5 / 60, 2) END   AS NestingHours,
            CASE WHEN OpRe.LinkIDProcessingStation IN ('1966O1PHUNP10','1966O9J0UOZ10')
                 THEN ROUND(OpRe.OptimizedQuantity * 3.5 / 60, 2) END   AS PanelHours,
            CASE WHEN OpRe.LinkIDProcessingStation IN ('1966O1PHUNP10','1966O9J0UOZ10')
                 THEN ROUND({p2p_select} * 5.0 / 60 * 1.12, 2) END     AS P2pHours,
            ROUND(ISNULL({miter_select}, 0) * 5.0 / 60, 2)              AS MiterHours,
            {edge_hours_select}                                          AS EdgingHours,
            ROUND(ISNULL(Solid.Qty, 0) * 5.0 / 60, 2)                  AS SolidHours,
            [WorkOrderBatches].[Name]                           AS BatchName
        FROM (
            SELECT
                SUM(CAST(OptimizationResults.OptimizedQuantity AS FLOAT)) AS OptimizedQuantity,
                OptimizationResults.LinkIDWorkOrder,
                OptimizationResults.LinkIDWorkOrderBatch,
                OptimizationResults.LinkIDProcessingStation
            FROM [{schema_name}].OptimizationResults
            WHERE OptimizationResults.ScrapType = 0
            GROUP BY
                OptimizationResults.LinkIDWorkOrder,
                OptimizationResults.LinkIDProcessingStation,
                OptimizationResults.LinkIDWorkOrderBatch
            HAVING SUM(CAST(OptimizationResults.OptimizedQuantity AS FLOAT)) > 0
        ) OpRe
        LEFT JOIN (
            SELECT
                COUNT(PlacedSheets.ID) AS [count],
                PlacedSheets.LinkIDProcessingStation,
                PlacedSheets.LinkIDWorkOrder,
                PlacedSheets.LinkIDWorkOrderBatch
            FROM [{schema_name}].PlacedSheets
            WHERE CAST(PlacedSheets.Width AS FLOAT) > 350
            GROUP BY
                PlacedSheets.LinkIDProcessingStation,
                PlacedSheets.LinkIDWorkOrder,
                PlacedSheets.LinkIDWorkOrderBatch
        ) Sheets
            ON  OpRe.LinkIDProcessingStation = Sheets.LinkIDProcessingStation
            AND OpRe.LinkIDWorkOrderBatch    = Sheets.LinkIDWorkOrderBatch
            AND OpRe.LinkIDWorkOrder         = Sheets.LinkIDWorkOrder
        LEFT JOIN (
            SELECT SUM(CAST([Products].[Quantity] AS FLOAT)) AS Product,
                   [Products].[LinkIDWorkOrder]
            FROM [{schema_name}].Products
            GROUP BY [Products].[LinkIDWorkOrder]
        ) Product ON OpRe.LinkIDWorkOrder = Product.LinkIDWorkOrder
        {edge_subquery}
        LEFT JOIN (
            SELECT SUM(CAST(OptimizationResults.OptimizedQuantity AS FLOAT)) AS Parts,
                   LinkIDWorkOrder
            FROM [{schema_name}].OptimizationResults
            WHERE OptimizationResults.ScrapType = 0
            GROUP BY LinkIDWorkOrder
        ) Part ON OpRe.LinkIDWorkOrder = Part.LinkIDWorkOrder
        INNER JOIN [{schema_name}].WorkOrderBatches
            ON OpRe.LinkIDWorkOrderBatch = [WorkOrderBatches].[LinkID]
        {p2p_subquery}
        {miter_subquery}
        LEFT JOIN (
            SELECT LinkIDWorkOrder,
                   CEILING(SUM(CAST(PlacedSheets.Quantity AS FLOAT) * CAST(PlacedSheets.Length AS FLOAT)) * 0.001) AS Qty
            FROM [{schema_name}].PlacedSheets
            WHERE PlacedSheets.Name LIKE '%Solid%'
              AND PlacedSheets.Name NOT LIKE '%Solid Surface%'
            GROUP BY LinkIDWorkOrder
        ) Solid ON OpRe.LinkIDWorkOrder = Solid.LinkIDWorkOrder
        ORDER BY [WorkOrderBatches].[Name], OpRe.LinkIDProcessingStation
        """

        cursor.execute(summary_query)
        columns = [desc[0] for desc in cursor.description]
        summary_rows = []
        for row in cursor.fetchall():
            row_dict = {}
            for idx, col in enumerate(columns):
                val = row[idx]
                if val is not None:
                    row_dict[col] = float(val) if isinstance(val, (int, float)) else str(val)
                else:
                    row_dict[col] = None
            summary_rows.append(row_dict)

        # Aggregate summary into a single object for the frontend
        # Hours will be recomputed from detail data using actual formulas
        summary = {
            'nest_sheets': 0, 'nest_parts': 0,
            'panel_sheets': 0, 'panel_parts': 0,
            'edge_linft': 0, 'p2p': 0, 'miter': 0, 'solid': 0,
            'products': 0, 'total_parts': 0,
            'elix_hours': 0, 'edging_hours': 0, 'cnc_hours': 0, 'miter_hours': 0,
            'batch_name': '',
        }
        for r in summary_rows:
            if r.get('NestSht'):
                summary['nest_sheets'] = int(r['NestSht'])
                summary['nest_parts'] = int(r['NestPrts'] or 0)
            if r.get('PnlSht'):
                summary['panel_sheets'] = int(r['PnlSht'])
                summary['panel_parts'] = int(r['PnlPrts'] or 0)
            if r.get('Edge') is not None:
                summary['edge_linft'] = round(float(r['Edge']), 0)
            if r.get('P2P') is not None:
                summary['p2p'] = int(r['P2P'])
            if r.get('Miter') is not None:
                summary['miter'] = int(r['Miter'])
            if r.get('Solid') is not None:
                summary['solid'] = int(r['Solid'])
            if r.get('Product') is not None:
                summary['products'] = int(r['Product'])
            if r.get('TtlPrts') is not None:
                summary['total_parts'] = int(r['TtlPrts'])
            if r.get('BatchName'):
                summary['batch_name'] = r['BatchName']

        # ================================================================
        # QUERY 2: Per-Sheet Detail
        # Uses correct LinkID joins with LTRIM/RTRIM
        # ================================================================
        drills_h_join = ""
        drills_h_select = "0 AS HorizontalDrills"
        drills_v_join = ""
        drills_v_select = "0 AS VerticalDrills"
        routes_join = ""
        routes_select = "0"
        eb_join = ""
        eb_select = "0"

        if has_drills_h:
            drills_h_join = f"LEFT JOIN [{schema_name}].DrillsHorizontal dh ON LTRIM(RTRIM(dh.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))"
            drills_h_select = "COUNT(DISTINCT dh.ID) AS HorizontalDrills"
        if has_drills_v:
            drills_v_join = f"LEFT JOIN [{schema_name}].DrillsVertical dv ON LTRIM(RTRIM(dv.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))"
            drills_v_select = "COUNT(DISTINCT dv.ID) AS VerticalDrills"
        if has_routes:
            routes_join = f"""LEFT JOIN [{schema_name}].Routes r
                ON LTRIM(RTRIM(r.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))"""
            routes_select = "ISNULL(SUM(DISTINCT CAST(r.TotalRouteLength AS FLOAT)), 0)"
        if has_edgebanding:
            eb_join = f"""LEFT JOIN [{schema_name}].Edgebanding eb
                ON LTRIM(RTRIM(eb.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))"""
            eb_select = "ISNULL(SUM(CAST(eb.LinFt AS FLOAT)), 0)"

        # Build dynamic column references for Parts table
        material_select = "pt.MaterialName" if has_material_name else "NULL"
        material_group = ", pt.MaterialName" if has_material_name else ""
        linkid_product_select = "pt.LinkIDProduct" if has_linkid_product else "NULL"
        linkid_product_group = ", pt.LinkIDProduct" if has_linkid_product else ""
        p2p_select_detail = """CASE WHEN LEN(LTRIM(RTRIM(ISNULL(pt.Face6Barcode, '')))) > 0
                     THEN 1 ELSE 0 END""" if has_face6barcode else "0"
        face6_group = ", pt.Face6Barcode" if has_face6barcode else ""
        miter_select_detail = """CASE WHEN pt.Comments LIKE '%@%'
                     THEN 1 ELSE 0 END""" if has_comments else "0"
        comments_group = ", pt.Comments" if has_comments else ""

        # Product join: use LinkIDProduct if available, else skip product info
        if has_linkid_product:
            product_join = f"""INNER JOIN [{schema_name}].Products p
            ON LTRIM(RTRIM(p.LinkID)) = LTRIM(RTRIM(pm.LinkIDProduct))"""
            product_name_select = "p.Name"
            product_qty_select = "CAST(p.Quantity AS INT)"
        else:
            product_join = f"""LEFT JOIN [{schema_name}].Products p
            ON LTRIM(RTRIM(p.LinkIDWorkOrder)) = LTRIM(RTRIM(pm.LinkIDWorkOrder))"""
            product_name_select = "ISNULL(p.Name, 'N/A')"
            product_qty_select = "ISNULL(CAST(p.Quantity AS INT), 0)"

        detail_query = f"""
        WITH PartMetrics AS (
            SELECT
                pt.LinkID                                   AS PartKey,
                pt.Name                                     AS PartName,
                CAST(pt.Length AS FLOAT)                     AS PartLength_mm,
                CAST(pt.Width AS FLOAT)                      AS PartWidth_mm,
                CAST(pt.Thickness AS FLOAT)                  AS PartThickness_mm,
                {material_select}                            AS PartMaterial,
                {linkid_product_select}                      AS LinkIDProduct,
                pt.LinkIDWorkOrder,
                {p2p_select_detail}                          AS IsP2P,
                {miter_select_detail}                        AS IsMiter,
                {routes_select}                              AS PartToolPath_mm,
                {eb_select}                                  AS PartEdgeBand_mm,
                {drills_h_select},
                {drills_v_select}
            FROM [{schema_name}].Parts pt
            {routes_join}
            {eb_join}
            {drills_h_join}
            {drills_v_join}
            GROUP BY
                pt.LinkID, pt.Name, pt.Length, pt.Width, pt.Thickness,
                pt.LinkIDWorkOrder{material_group}{linkid_product_group}{face6_group}{comments_group}
        )
        SELECT
            wob.[Name]                                      AS BatchName,
            CASE ps.LinkIDProcessingStation
                WHEN '21BMOJSH9M90'  THEN 'CNC Nesting'
                WHEN '1966O1PHUNP10' THEN 'Panel Saw'
                WHEN '1966O9J0UOZ10' THEN 'Panel Saw'
                ELSE ps.LinkIDProcessingStation
            END                                             AS StationName,
            ps.LinkIDProcessingStation                      AS StationID,
            ps.Name                                         AS MaterialName,
            CAST(ps.[Index] AS INT)                         AS SheetNumber,
            CAST(ps.Length AS INT)                           AS SheetLength_mm,
            CAST(ps.Width AS INT)                            AS SheetWidth_mm,
            {product_name_select}                            AS ProductName,
            {product_qty_select}                             AS ProductQty,
            pm.PartName,
            CAST(pm.PartLength_mm AS INT)                   AS PartLength_mm,
            CAST(pm.PartWidth_mm AS INT)                    AS PartWidth_mm,
            pm.PartMaterial,
            ROUND(pm.PartToolPath_mm / 1000.0, 2)          AS Part_ToolPath_m,
            ROUND(pm.PartEdgeBand_mm / 1000.0, 2)          AS Part_EdgeBand_m,
            ROUND((pm.PartLength_mm * pm.PartWidth_mm) / 1000000.0, 4) AS Part_Area_sqm,
            pm.IsP2P,
            pm.IsMiter,
            pm.HorizontalDrills,
            pm.VerticalDrills
        FROM [{schema_name}].PlacedSheets ps
        INNER JOIN [{schema_name}].OptimizationResults opt
            ON LTRIM(RTRIM(opt.LinkIDSheet)) = LTRIM(RTRIM(ps.LinkID))
           AND opt.ScrapType = 0
        INNER JOIN PartMetrics pm
            ON LTRIM(RTRIM(pm.PartKey)) = LTRIM(RTRIM(opt.LinkIDPart))
        {product_join}
        INNER JOIN [{schema_name}].WorkOrderBatches wob
            ON LTRIM(RTRIM(wob.LinkID)) = LTRIM(RTRIM(ps.LinkIDWorkOrderBatch))
        ORDER BY
            wob.[Name],
            ps.LinkIDProcessingStation,
            ps.[Index],
            pm.PartName
        """

        cursor.execute(detail_query)
        detail_columns = [desc[0] for desc in cursor.description]

        # Build hierarchical: Station -> Material -> Sheets (with parts)
        processing_stations = {}

        for row in cursor.fetchall():
            r = {}
            for idx, col in enumerate(detail_columns):
                r[col] = row[idx]

            station_id = r['StationID'] or 'Unassigned'
            station_name = r['StationName'] or station_id
            material = r['MaterialName'] or 'Unknown'
            sheet_num = r['SheetNumber']

            # Init station
            if station_id not in processing_stations:
                processing_stations[station_id] = {
                    'station_id': station_id,
                    'station_name': station_name,
                    'materials': {}
                }

            # Init material
            if material not in processing_stations[station_id]['materials']:
                processing_stations[station_id]['materials'][material] = {
                    'material_name': material,
                    'sheets': {},
                    'products': {}
                }

            mat = processing_stations[station_id]['materials'][material]

            # Init sheet
            if sheet_num not in mat['sheets']:
                mat['sheets'][sheet_num] = {
                    'sheet_number': sheet_num,
                    'length_mm': r['SheetLength_mm'] or 0,
                    'width_mm': r['SheetWidth_mm'] or 0,
                    'parts': []
                }

            # Add part to sheet
            mat['sheets'][sheet_num]['parts'].append({
                'name': r['PartName'] or '',
                'length_mm': r['PartLength_mm'] or 0,
                'width_mm': r['PartWidth_mm'] or 0,
                'material': r['PartMaterial'] or '',
                'toolpath_m': float(r['Part_ToolPath_m'] or 0),
                'edgeband_m': float(r['Part_EdgeBand_m'] or 0),
                'area_sqm': float(r['Part_Area_sqm'] or 0),
                'is_p2p': int(r['IsP2P'] or 0),
                'is_miter': int(r['IsMiter'] or 0),
                'h_drills': int(r['HorizontalDrills'] or 0),
                'v_drills': int(r['VerticalDrills'] or 0),
                'product_name': r['ProductName'] or '',
                'product_qty': int(r['ProductQty'] or 0),
            })

            # Track products
            prod_name = r['ProductName'] or ''
            if prod_name and prod_name not in mat['products']:
                mat['products'][prod_name] = {
                    'name': prod_name,
                    'quantity': int(r['ProductQty'] or 0)
                }

        conn.close()

        # Convert to list format
        stations_list = []
        for sid, sdata in processing_stations.items():
            materials_list = []
            for mname, mdata in sdata['materials'].items():
                sheets_list = sorted(mdata['sheets'].values(), key=lambda s: s['sheet_number'])
                products_list = sorted(mdata['products'].values(), key=lambda p: p['name'])
                materials_list.append({
                    'material_name': mname,
                    'sheet_count': len(sheets_list),
                    'part_count': sum(len(s['parts']) for s in sheets_list),
                    'products': products_list,
                    'sheets': sheets_list,
                })
            stations_list.append({
                'station_id': sdata['station_id'],
                'station_name': sdata['station_name'],
                'materials': materials_list,
            })

        # ================================================================
        # Compute hours from detail data using actual formulas:
        #   Elix time     = total H.Drills * 8 sec
        #   Edging time   = total edge length (mm) / 12000 mm/min
        #   CNC time      = total toolpath (mm) / 8000 mm/min
        #   Miter time    = miter count * 8 min
        # ================================================================
        total_h_drills = 0
        total_edgeband_mm = 0
        total_toolpath_mm = 0
        total_miters = 0

        for station in stations_list:
            for material in station['materials']:
                for sheet in material['sheets']:
                    for part in sheet['parts']:
                        total_h_drills += part.get('h_drills', 0)
                        # edgeband_m and toolpath_m are in meters, convert back to mm
                        total_edgeband_mm += part.get('edgeband_m', 0) * 1000
                        total_toolpath_mm += part.get('toolpath_m', 0) * 1000
                        if part.get('is_miter'):
                            total_miters += 1

        # Elix: H.Drills * 8 sec → hours
        summary['elix_hours'] = round(total_h_drills * 8 / 3600, 2)
        # Edging: total mm / 12000 mm per min → hours
        summary['edging_hours'] = round(total_edgeband_mm / 12000 / 60, 2)
        # CNC: total toolpath mm / 8000 mm per min → hours
        summary['cnc_hours'] = round(total_toolpath_mm / 8000 / 60, 2)
        # Miter: count * 8 min → hours
        summary['miter_hours'] = round(total_miters * 8 / 60, 2)

        # Also provide raw totals for frontend display
        summary['total_h_drills'] = total_h_drills
        summary['total_edgeband_mm'] = round(total_edgeband_mm, 0)
        summary['total_toolpath_mm'] = round(total_toolpath_mm, 0)
        summary['total_miters'] = total_miters

        return {
            'schema_name': schema_name,
            'summary': summary,
            'processing_stations': stations_list,
            'total_stations': len(stations_list),
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/query")
def execute_query(request: QueryRequest):
    """Execute a custom SQL query (SELECT only for safety)"""
    try:
        query = request.query.strip()

        if not query:
            raise HTTPException(status_code=400, detail="Empty query")

        # Safety check - only allow SELECT
        query_upper = query.upper()
        if not query_upper.startswith('SELECT'):
            raise HTTPException(status_code=403, detail="Only SELECT queries are allowed")

        dangerous_keywords = ['DROP', 'DELETE', 'TRUNCATE', 'ALTER', 'INSERT', 'UPDATE', 'CREATE']
        for keyword in dangerous_keywords:
            if keyword in query_upper:
                raise HTTPException(status_code=403, detail=f"Dangerous keyword detected: {keyword}")

        conn = get_connection()
        cursor = conn.cursor()

        start_time = datetime.now()
        cursor.execute(query)

        # Get column names
        columns = [desc[0] for desc in cursor.description] if cursor.description else []

        # Get results (limit to 1000 rows)
        rows = []
        for idx, row in enumerate(cursor.fetchall()):
            if idx >= 1000:
                break
            row_dict = {}
            for col_idx, col in enumerate(columns):
                value = row[col_idx]
                row_dict[col] = str(value) if value is not None else None
            rows.append(row_dict)

        execution_time = (datetime.now() - start_time).total_seconds()

        conn.close()

        return {
            'columns': columns,
            'rows': rows,
            'row_count': len(rows),
            'execution_time': execution_time,
            'truncated': len(rows) >= 1000
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/sheet-tracking")
def sheet_tracking(request: SheetTrackingRequest):
    """Execute sheet tracking query with scrap analysis"""
    try:
        schema = request.schema_name
        scrapped_sheet = request.scrapped_sheet_number
        scrapped_station = request.scrapped_station

        query = f"""
        WITH SheetProcessing AS (
            SELECT
                p.ID as PartID,
                p.Name as PartName,
                CAST(p.Length as FLOAT) as Length,
                CAST(p.Width as FLOAT) as Width,
                CAST(p.Thickness as FLOAT) as Thickness,
                p.MaterialName,
                opt.[Index] as OptIndex,
                ps.[Index] as SheetNumber,
                ps.Name as SheetName,
                pps.LinkIDProcessingStation,
                ROW_NUMBER() OVER (PARTITION BY p.ID ORDER BY pps.ID) as ProcessSequence
            FROM [{schema}].Parts p
            INNER JOIN [{schema}].OptimizationResults opt
                ON opt.LinkIDPart = p.ID
            INNER JOIN [{schema}].PlacedSheets ps
                ON ps.LinkIDWorkOrderBatch = opt.LinkIDWorkOrderBatch
                AND ps.[Index] = opt.[Index] + 1
            LEFT JOIN [{schema}].PartsProcessingStations pps
                ON pps.LinkIDPart = p.ID
        ),
        PartMetrics AS (
            SELECT
                PartID,
                PartName,
                Length,
                Width,
                Thickness,
                MaterialName,
                SheetNumber,
                SheetName,
                COUNT(DISTINCT LinkIDProcessingStation) as TotalStations
            FROM SheetProcessing
            GROUP BY PartID, PartName, Length, Width, Thickness, MaterialName, SheetNumber, SheetName
        )
        SELECT
            pm.SheetNumber,
            pm.SheetName,
            pm.PartName,
            pm.Length,
            pm.Width,
            pm.Thickness,
            pm.MaterialName,
            sp.LinkIDProcessingStation,
            sp.ProcessSequence,
            pm.TotalStations,
            CASE
                WHEN {scrapped_sheet} IS NOT NULL
                    AND pm.SheetNumber = {scrapped_sheet}
                    AND sp.ProcessSequence <= {scrapped_station if scrapped_station else 'pm.TotalStations'}
                THEN 'SCRAPPED'
                ELSE 'OK'
            END as Status
        FROM PartMetrics pm
        LEFT JOIN SheetProcessing sp
            ON sp.PartID = pm.PartID
            AND sp.SheetNumber = pm.SheetNumber
        ORDER BY pm.SheetNumber, pm.PartName, sp.ProcessSequence
        """

        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute(query)

        columns = [desc[0] for desc in cursor.description]
        rows = []
        for row in cursor.fetchall():
            row_dict = {}
            for idx, col in enumerate(columns):
                value = row[idx]
                row_dict[col] = str(value) if value is not None else None
            rows.append(row_dict)

        conn.close()

        return {
            'columns': columns,
            'rows': rows,
            'row_count': len(rows)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Serve frontend static files (CSS, JS)
FRONTEND_DIR = Path(__file__).parent.parent / "frontend"
if FRONTEND_DIR.exists():
    app.mount("/css", StaticFiles(directory=str(FRONTEND_DIR / "css")), name="css")
    app.mount("/js", StaticFiles(directory=str(FRONTEND_DIR / "js")), name="js")

    @app.get("/app", include_in_schema=False)
    def serve_frontend():
        """Serve the frontend index.html"""
        return FileResponse(str(FRONTEND_DIR / "index.html"))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8001, reload=True)
