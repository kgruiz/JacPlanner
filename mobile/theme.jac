import from "@jac/mobui" { StyleSheet }

glob:pub styles = StyleSheet.create(
         {
             "screen": {"flex": 1, "backgroundColor": "#F7F5EF"},
             "body": {"padding": 22, "paddingTop": 66, "paddingBottom": 44, "gap": 18},
             "heading": {"color": "#192D3A", "fontSize": 32, "fontWeight": "bold"},
             "subtitle": {"color": "#596B73", "fontSize": 16, "lineHeight": 23},
             "label": {"color": "#192D3A", "fontSize": 16, "fontWeight": "600"},
             "row": {
                 "flexDirection": "row",
                 "gap": 10,
                 "alignItems": "center",
                 "flexWrap": "wrap"
             },
             "card": {
                 "backgroundColor": "#FFFFFF",
                 "borderRadius": 18,
                 "padding": 18,
                 "gap": 10,
                 "borderWidth": 1,
                 "borderColor": "#DFE5DE"
             },
             "input": {
                 "backgroundColor": "#FFFFFF",
                 "borderWidth": 1,
                 "borderColor": "#B9C6C6",
                 "borderRadius": 10,
                 "padding": 13,
                 "fontSize": 16,
                 "color": "#192D3A",
                 "minHeight": 48
             },
             "button": {
                 "backgroundColor": "#176F68",
                 "borderRadius": 12,
                 "padding": 14,
                 "minHeight": 48,
                 "alignItems": "center"
             },
             "buttonText": {"color": "#FFFFFF", "fontSize": 16, "fontWeight": "600"},
             "secondary": {
                 "backgroundColor": "#E5EEEA",
                 "borderRadius": 12,
                 "padding": 14,
                 "minHeight": 48,
                 "alignItems": "center"
             },
             "secondaryText": {"color": "#155D58", "fontSize": 16, "fontWeight": "600"},
             "error": {"color": "#9B3430", "fontSize": 16, "lineHeight": 23},
             "metric": {"color": "#176F68", "fontSize": 28, "fontWeight": "bold"},
             "notes": {"color": "#596B73", "fontSize": 15, "lineHeight": 22}
         }
     );
