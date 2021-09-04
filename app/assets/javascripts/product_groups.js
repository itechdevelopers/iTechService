$(function() {
  if ($('#product_groups').length > 0) {
    return product_groups_tree('#product_groups');
  }
});

window.product_groups_tree = function(container) {
  $.jstree._themes = "/assets/jstree/";
  const $container = $(container);
  const root_id = $container.data('root_id');
  let group_id = $container.data('product_group_id');
  const opened = $container.data('opened');
  $container.bind("create.jstree", function(e, data) {
    return $.post("/product_groups/", {
      parent_id: data.rslt.parent[0].id,
      product_group_name: data.rslt.name
    }, function(new_id) {
      return $("li:not([id*=product_group_])", $container).attr("id", "product_group_" + new_id);
    });
  }).bind("remove.jstree", function(e, data) {
    return $.ajax({
      type: "DELETE",
      url: "/product_groups/" + (data.rslt.obj[0].id.replace("product_group_", ""))
    });
  }).bind("rename.jstree", function(e, data) {
    return $.ajax({
      type: "PUT",
      url: "/product_groups/" + (data.rslt.obj[0].id.replace("product_group_", "")),
      data: {
        product_group: {
          name: data.rslt.new_name
        }
      }
    });
  }).bind('select_node.jstree', function(e, data) {
    return $container.jstree('open_node', data.rslt.obj[0]);
  }).bind("move_node.jstree", function(e, {rslt}) {
    const product_group_id = rslt.o[0].dataset.productGroupId
    const parent_id = rslt.np[0].dataset.productGroupId
    const position = rslt.cp + 1
    $.ajax({
      type: "PUT",
      url: "/product_groups/" + product_group_id,
      data: {
        product_group: {
          parent_id: parent_id,
          position: position
        }
      }
    })
  }).jstree({
    core: {
      strings: {
        loading: "Загружаю...",
        new_node: "Новая Продуктовая Группа"
      },
      initially_open: opened,
      load_open: true,
      open_parents: true,
      animation: 10
    },
    themes: {
      theme: "apple",
      dots: false,
      icons: false
    },
    ui: {
      select_limit: 1
    },
    contextmenu: {
      select_node: true,
      items: {
        create: {
          label: "Создать",
          action: function(obj) {
            group_id = obj[0].id.replace("product_group_", "");
            return $.get("/product_groups/new.js", {
              product_group: {
                parent_id: group_id
              }
            });
          },
          separator_after: true
        },
        rename: {
          label: "Редактировать",
          action: function(obj) {
            group_id = obj[0].id.replace("product_group_", "");
            return $.get("/product_groups/" + group_id + "/edit.js");
          },
          separator_after: true
        },
        remove: {
          label: "Удалить",
          action: function(obj) {
            if (confirm("Вы уверены?")) {
              if (this.is_selected(obj)) {
                return this.remove();
              } else {
                return this.remove(obj);
              }
            }
          }
        }
      }
    },
    plugins: ["themes", "html_data", "ui", "contextmenu", "crrm", "dnd"]
  }).show();
};

window.product_groups_tree_readonly = function(container) {
  var $container, root_id;
  $.jstree._themes = "/assets/jstree/";
  $container = $(container);
  root_id = $container.data('root_id');
  return $container.bind('select_node.jstree', function(e, data) {
    return $container.jstree('open_node', data.rslt.obj[0]);
  }).jstree({
    core: {
      strings: {
        loading: "Загружаю...",
        new_node: "Новая Продуктовая Группа"
      },
      load_open: true,
      open_parents: true,
      animation: 10
    },
    themes: {
      theme: "apple",
      dots: false,
      icons: false
    },
    ui: {
      select_limit: 1
    },
    plugins: ["themes", "html_data", "ui"]
  }).show();
};
