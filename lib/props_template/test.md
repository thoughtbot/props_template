array
handle_collection
  all_opts = collection.map do |item|
    refine_item_options(item, options)
  end
  creates clone of the opts using 
  refine_item_options clones original options
    then subsequently the ext refine_item_options
    gets called first, 

  refine_all_item_options <- operates on the entire collection

  handle_collection_item
    set_content options


 
base with ExtensionManager
    refine_all_item_options - overrided with ext manager
      - which attahes a _template with partialer
       to it AND multifetch and attaches it to cache
       as [key, result]

    refine_item_options
      - transforms key: :id to key = [key, val]
      - passes to refine_options
          which is then asks the searcher the cache and
          deferment to mutate the option