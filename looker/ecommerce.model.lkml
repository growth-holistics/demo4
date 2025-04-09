connection: "demodb"

include: "*.view.lkml"         # include all views in this project
include: "*.dashboard.lookml"  # include all dashboards in this project

explore: order_items {
  join: orders {
    sql_on: ${order_items.order_id} = ${orders.id} ;;
    type: left_outer
    relationship: one_to_many
  }
  join: users {
    type: left_outer
    relationship: many_to_one
    sql_on: ${orders.user_id} = ${users.id} ;;
  }
  join: products {
    type: left_outer
    relationshio: many_to_one
    sql_on: ${order_items.product_id} = ${products.id} ;;
  }
}

explore: users {}
