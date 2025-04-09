view: products {
  sql_table_name: ecommerce.products ;;

  dimension: d {
    type: number
    sql: ${TABLE}.id ;;
    primary_key: yes
    hidden: yes
  }

# ------------------------------------------------ Product Info

  dimension: title {
    type: string
    sql: ${TABLE}.title ;;
  }

  dimension: product_type {
    type: string
    sql: ${TABLE}.product_type ;;
  }
# ------------------------------------------------ Dates
  dimension: created_at {
    type: date
    sql: ${TABLE}.created_at ;;
  }

  dimension: deleted_at {
    type: date
    sql: ${TABLE}.deleted_at ;;
  }

# ------------------------------------------------ Measures

}
