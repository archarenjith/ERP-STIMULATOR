"""Small, coherent manufacturing master data set used by the event generator."""

SUPPLIERS = [
    {"supplier_id": "SUP-001", "supplier_name": "Apex Metals", "country": "IN", "rating": "A"},
    {"supplier_id": "SUP-002", "supplier_name": "Precision Polymers", "country": "IN", "rating": "A"},
    {"supplier_id": "SUP-003", "supplier_name": "Northstar Components", "country": "DE", "rating": "B"},
    {"supplier_id": "SUP-004", "supplier_name": "Volt Materials", "country": "IN", "rating": "B"},
    {"supplier_id": "SUP-005", "supplier_name": "Industrial Fasteners Co", "country": "CN", "rating": "A"},
    {"supplier_id": "SUP-006", "supplier_name": "CleanPack Solutions", "country": "IN", "rating": "A"},
]

MATERIALS = [
    {"material_id": "RM-STEEL", "material_name": "Steel sheet", "uom": "kg", "reorder_level": 2000},
    {"material_id": "RM-ALUM", "material_name": "Aluminium billet", "uom": "kg", "reorder_level": 1500},
    {"material_id": "RM-RESIN", "material_name": "Polymer resin", "uom": "kg", "reorder_level": 1200},
    {"material_id": "RM-COPPER", "material_name": "Copper wire", "uom": "kg", "reorder_level": 600},
    {"material_id": "RM-BOLT", "material_name": "Fastener kit", "uom": "each", "reorder_level": 8000},
    {"material_id": "RM-PAINT", "material_name": "Powder coating", "uom": "kg", "reorder_level": 300},
    {"material_id": "RM-PACK", "material_name": "Packaging set", "uom": "each", "reorder_level": 2000},
    {"material_id": "RM-LUBE", "material_name": "Machine lubricant", "uom": "litre", "reorder_level": 150},
]

PRODUCTS = [
    {"product_id": "FG-100", "product_name": "Industrial Pump 100", "uom": "each", "standard_cycle_minutes": 45},
    {"product_id": "FG-200", "product_name": "Industrial Pump 200", "uom": "each", "standard_cycle_minutes": 60},
    {"product_id": "FG-300", "product_name": "Control Housing", "uom": "each", "standard_cycle_minutes": 25},
    {"product_id": "FG-400", "product_name": "Valve Assembly", "uom": "each", "standard_cycle_minutes": 20},
    {"product_id": "FG-500", "product_name": "Motor Bracket", "uom": "each", "standard_cycle_minutes": 18},
    {"product_id": "FG-600", "product_name": "Sensor Enclosure", "uom": "each", "standard_cycle_minutes": 15},
]

MACHINES = [
    {"machine_id": "MC-01", "machine_name": "CNC Mill 01", "work_center": "Machining", "rated_kw": 18.5},
    {"machine_id": "MC-02", "machine_name": "CNC Mill 02", "work_center": "Machining", "rated_kw": 18.5},
    {"machine_id": "MC-03", "machine_name": "Injection Moulder", "work_center": "Moulding", "rated_kw": 32.0},
    {"machine_id": "MC-04", "machine_name": "Assembly Line A", "work_center": "Assembly", "rated_kw": 12.0},
    {"machine_id": "MC-05", "machine_name": "Powder Coater", "work_center": "Finishing", "rated_kw": 24.0},
]

EMPLOYEES = [
    {"employee_id": f"EMP-{number:03}", "employee_name": f"Operator {number:02}", "role": role}
    for number, role in enumerate(
        ["operator", "operator", "operator", "operator", "technician", "technician", "inspector", "inspector", "supervisor", "operator", "operator", "operator"],
        start=1,
    )
]


def all_reference_records() -> list[tuple[str, dict]]:
    """Return (entity type, payload) pairs in a stable order."""
    records: list[tuple[str, dict]] = []
    for entity_type, dataset in (
        ("supplier", SUPPLIERS),
        ("material", MATERIALS),
        ("product", PRODUCTS),
        ("machine", MACHINES),
        ("employee", EMPLOYEES),
    ):
        records.extend((entity_type, record) for record in dataset)
    return records
