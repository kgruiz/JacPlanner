import from "@jac/mobui" { StyleSheet }

glob:pub styles = StyleSheet.create(
         {
             "screen": {"flex": 1, "backgroundColor": "#FFFFFF"},
             "header": {
                 "paddingHorizontal": 20,
                 "paddingTop": 62,
                 "paddingBottom": 14,
                 "gap": 18
             },
             "headerRow": {
                 "flexDirection": "row",
                 "alignItems": "center",
                 "justifyContent": "space-between"
             },
             "heading": {"color": "#101B31", "fontSize": 34, "fontWeight": "700"},
             "subtitle": {"color": "#627086", "fontSize": 17, "lineHeight": 24},
             "add": {"color": "#0066FF", "fontSize": 36, "padding": 8},
             "week": {"flexDirection": "row", "justifyContent": "space-between"},
             "day": {"alignItems": "center", "gap": 7, "flex": 1},
             "dayNumber": {
                 "fontSize": 21,
                 "color": "#101B31",
                 "textAlign": "center",
                 "width": 42,
                 "height": 42,
                 "paddingTop": 8
             },
             "selectedDay": {
                 "fontSize": 21,
                 "color": "#FFFFFF",
                 "backgroundColor": "#0066FF",
                 "borderRadius": 21,
                 "textAlign": "center",
                 "overflow": "hidden",
                 "width": 42,
                 "height": 42,
                 "paddingTop": 8
             },
             "body": {"paddingHorizontal": 16, "paddingBottom": 18, "gap": 18},
             "label": {"color": "#101B31", "fontSize": 16, "fontWeight": "600"},
             "detail": {"color": "#65738A", "fontSize": 12, "lineHeight": 18},
             "row": {
                 "flexDirection": "row",
                 "gap": 10,
                 "alignItems": "center",
                 "flexWrap": "wrap"
             },
             "card": {
                 "backgroundColor": "#F6F8FB",
                 "borderRadius": 14,
                 "padding": 16,
                 "gap": 12,
                 "borderWidth": 1,
                 "borderColor": "#E2E7F0"
             },
             "input": {
                 "backgroundColor": "#FFFFFF",
                 "borderWidth": 1,
                 "borderColor": "#CDD6E5",
                 "borderRadius": 10,
                 "padding": 12,
                 "fontSize": 16,
                 "color": "#101B31",
                 "minHeight": 46
             },
             "button": {
                 "backgroundColor": "#0066FF",
                 "borderRadius": 10,
                 "padding": 13,
                 "minHeight": 46,
                 "alignItems": "center"
             },
             "buttonText": {"color": "#FFFFFF", "fontSize": 15, "fontWeight": "600"},
             "secondary": {
                 "backgroundColor": "#EAF1FF",
                 "borderRadius": 10,
                 "padding": 13,
                 "minHeight": 46,
                 "alignItems": "center"
             },
             "secondaryText": {"color": "#0066FF", "fontSize": 14, "fontWeight": "500"},
             "error": {"color": "#AE3434", "fontSize": 15, "lineHeight": 22},
             "banner": {
                 "backgroundColor": "#F1F4F9",
                 "borderRadius": 11,
                 "padding": 14,
                 "gap": 4
             },
             "hour": {"color": "#65738A", "fontSize": 11, "width": "16%"},
             "rule": {"height": 1, "backgroundColor": "#E5EAF2", "flex": 1},
             "timelineTask": {
                 "position": "absolute",
                 "backgroundColor": "#F5F7FB",
                 "borderWidth": 1,
                 "borderColor": "#E3E9F3",
                 "borderLeftWidth": 5,
                 "borderRadius": 7,
                 "paddingHorizontal": 8,
                 "paddingVertical": 5,
                 "overflow": "hidden"
             },
             "taskTitle": {"color": "#101B31", "fontSize": 14, "fontWeight": "600"},
             "taskCard": {
                 "backgroundColor": "#F5F7FB",
                 "borderRadius": 8,
                 "borderLeftWidth": 4,
                 "padding": 12,
                 "gap": 10
             },
             "nowLabel": {"color": "#F12B49", "fontSize": 10, "width": "16%"},
             "nowRule": {"height": 1, "backgroundColor": "#F12B49", "flex": 1},
             "tray": {
                 "marginHorizontal": 16,
                 "marginVertical": 10,
                 "padding": 14,
                 "backgroundColor": "#F7F9FC",
                 "borderRadius": 10,
                 "borderWidth": 1,
                 "borderColor": "#DFE5EF"
             },
             "tabs": {
                 "flexDirection": "row",
                 "borderTopWidth": 1,
                 "borderColor": "#E5EAF2",
                 "paddingTop": 9,
                 "paddingBottom": 28
             },
             "tab": {"flex": 1, "alignItems": "center", "gap": 4},
             "tabIcon": {"color": "#0066FF", "fontSize": 25}
         }
     );
