view: users {
  sql_table_name: ecommerce.users ;;

  dimension: id {
    type: number
    sql: ${TABLE}.id ;;
    primary_key: yes
    hidden: yes
  }

# ------------------------------------------------ Customer Info
  dimension: first_name {
    type: string
    sql: ${TABLE}.first_name ;;
  }

  dimension: last_name {
    type: string
    sql: ${TABLE}.last_name ;;
  }

  dimension: full_name {
    type: string
    sql: concat(${TABLE}.first_name, ' ', ${TABLE}.last_name)
  }

  dimension: full_name_native {
    type: string
    sql: concat(${first_name}, ' ', ${last_name})
  }

  dimension: full_name_combine {
    type: string
    sql: concat(${first_name}, ' ', ${TABLE}.last_name)
  }

  dimension: email {
    type: string
    sql: ${TABLE}.email ;;
  }

  dimension: phone {
    type: string
    sql: ${TABLE}.phone ;;
  }

# ------------------------------------------------ Dates

  dimension_group: created {
    type: time
    timeframes: [
      raw,
      time,
      date,
      week,
      month,
      quarter,
      year
    ]
    sql: ${TABLE}.created_at ;;
  }

  dimension_group: first_order {
    type: time
    timeframes: [
      raw,
      time,
      date,
      week,
      month,
      quarter,
      year
    ]
    sql: ${TABLE}.first_order_date ;;
  }

}
